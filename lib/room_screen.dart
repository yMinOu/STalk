import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math';
import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bannerAd.dart';
import 'frontAd.dart';
import 'home_screen.dart';

int globalButtonPressCount = 0;

class RoomScreen extends StatefulWidget {
  final String roomName; // 방 이름
  final int roomNumber; // 방 번호
  final bool isWhite;   // 초기 배경색 (true: 흰색, false: 회색)
  final String myId;    // HomeScreen에서 전달된 사용자 아이디

  RoomScreen({
    required this.roomName,
    required this.roomNumber,
    required this.isWhite,
    required this.myId,
  });

  @override
  _RoomScreenState createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final FrontAdManager frontAdManager = FrontAdManager();

  static bool _blockCleared = false;
  String myId = '';
  late bool _isWhite;
  late ScrollController _scrollController;
  bool _isBanned = false; // banned 여부

  String? sessionId;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _controller = TextEditingController();
  bool connected = false;
  bool waitingForUser = true;
  bool _hasLeftRoom = false;
  bool wasConnected = false;
  bool chatTerminated = false;

  @override
  void initState() {
    super.initState();
    _loadOrCreateUserId();
    _isWhite = widget.isWhite;
    _scrollController = ScrollController();
    frontAdManager.loadAd();
  }

  Future<void> _loadOrCreateUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedId = prefs.getString('user_id');

    if (savedId == null) {
      savedId = Random().nextInt(100000).toString();
      await prefs.setString('user_id', savedId);
    }

    setState(() {
      myId = savedId!;
    });

    DataSnapshot bannedSnapshot = await _dbRef.child("bannedUsers").child(myId).get();
    if (bannedSnapshot.exists && bannedSnapshot.value == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: Text("사용 불가"),
              content: Text("당신의 계정은 일시 정지되었습니다."),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => HomeScreen(isWhite: _isWhite, myId: myId)),
                          (route) => false,
                    );
                  },
                  child: Text("확인"),
                )
              ],
            );
          },
        );
      });
      return;
    }

    if (!_blockCleared) {
      await _dbRef.child("blocked").child(myId).remove();
      _blockCleared = true;
    }

    _joinRoom();
  }

  // 추가: 두 사용자 간 차단 여부 확인
  Future<bool> _isBlocked(String userA, String userB) async {
    DataSnapshot snapshot =
    await _dbRef.child("blocked").child(userA).child(userB).get();
    return snapshot.exists && snapshot.value == true;
  }

  void _openReportDialog() async {
    if (sessionId == null) return;
    DatabaseReference messagesRef = _dbRef.child("rooms/${widget.roomNumber}/$sessionId/messages");
    DataSnapshot snapshot = await messagesRef.get();
    if (!snapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("신고할 메시지가 없습니다.")));
      return;
    }
    Map<dynamic, dynamic> messagesMap = snapshot.value as Map<dynamic, dynamic>;
    List<Map<String, dynamic>> messagesList = messagesMap.entries
        .where((e) => e.value["id"] != myId)
        .map((e) {
      return {
        "key": e.key,
        "id": e.value["id"],
        "message": e.value["message"],
        "timestamp": e.value["timestamp"],
      };
    }).toList();

    if (messagesList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("신고할 상대 메시지가 없습니다.")));
      return;
    }

    messagesList.sort((a, b) => a["timestamp"].compareTo(b["timestamp"]));
    String? selectedMessage;
    String? reportedOpponentId;

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text("신고할 메시지 선택"),
                content: Container(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: messagesList.length,
                    itemBuilder: (context, index) {
                      String messageText = messagesList[index]["message"];
                      return ListTile(
                        title: Text(messageText),
                        selected: selectedMessage == messageText,
                        onTap: () {
                          setState(() {
                            selectedMessage = messageText;
                            reportedOpponentId = messagesList[index]["id"];
                          });
                        },
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text("취소"),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (selectedMessage != null && reportedOpponentId != null) {
                        await _reportSelectedMessage(selectedMessage!, reportedOpponentId!);
                        Navigator.pop(context);
                        if (sessionId != null) {
                          await _dbRef.child("rooms/${widget.roomNumber}/$sessionId")
                              .update({'terminated': true});
                          setState(() {
                            chatTerminated = true;
                            connected = false;
                            waitingForUser = false;
                          });
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("메시지를 선택하세요.")));
                      }
                    },
                    child: Text("전송"),
                  ),
                ],
              );
            },
          );
        }
    );
  }

  Future<void> _reportSelectedMessage(String reportedMessage, String opponentId) async {
    await _dbRef.child("reports").push().set({
      "myId": myId,
      "opponentId": opponentId,
      "reportedMessage": reportedMessage,
      "timestamp": ServerValue.timestamp,
    });
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("신고가 완료되었습니다.")));
  }

  Future<void> _onFindOpponentPressed() async {
    globalButtonPressCount++;
    if (globalButtonPressCount % 8 == 0 && frontAdManager.isAdLoaded) {
      await frontAdManager.showAd();
    }
  }

  String generateSessionId() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<void> _joinRoom() async {
    DatabaseReference roomRef = _dbRef.child("rooms/${widget.roomNumber}");
    String? foundSessionId;

    DatabaseEvent roomEvent = await roomRef.once();
    if (roomEvent.snapshot.value != null) {
      Map<dynamic, dynamic> roomData = roomEvent.snapshot.value as Map<dynamic, dynamic>;
      for (var entry in roomData.entries) {
        var key = entry.key;
        var value = entry.value;
        if (value is Map && !(value['terminated'] ?? false) && value.containsKey('users')) {
          Map<dynamic, dynamic> usersMap = value['users'];
          if (usersMap.isEmpty) {
            foundSessionId = key;
            break;
          } else {
            String opponentId = usersMap.keys.first;
            bool iBlocked = await _isBlocked(myId, opponentId);
            bool blockedMe = await _isBlocked(opponentId, myId);
            if (!iBlocked && !blockedMe) {
              foundSessionId = key;
              break;
            }
          }
        }
      }
    }

    if (foundSessionId == null) {
      foundSessionId = generateSessionId();
      await roomRef.child(foundSessionId).set({'terminated': false});
    }

    sessionId = foundSessionId;

    await roomRef.child("$sessionId/users/$myId").set({
      "id": myId,
      "joined": DateTime.now().millisecondsSinceEpoch,
    });
    await roomRef.child("$sessionId/users/$myId").onDisconnect().remove();
    await roomRef.child("$sessionId/lastActivity").onDisconnect().set(ServerValue.timestamp);
    await roomRef.child("$sessionId/terminated").onDisconnect().set(true);

    _dbRef.child("rooms/${widget.roomNumber}/$sessionId/terminated").onValue.listen((event) {
      if (event.snapshot.value != null && event.snapshot.value == true) {
        setState(() {
          chatTerminated = true;
          connected = false;
          waitingForUser = false;
        });
      }
    });

    _checkUsersInRoom(sessionId!);
  }

  void _checkUsersInRoom(String sessionId) {
    _dbRef.child("rooms/${widget.roomNumber}/$sessionId/users").onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> usersMap = event.snapshot.value as Map<dynamic, dynamic>;
        int userCount = usersMap.length;
        if (userCount == 2) {
          setState(() {
            connected = true;
            waitingForUser = false;
            wasConnected = true;
            chatTerminated = false;
          });
        } else if (userCount == 1) {
          if (wasConnected) {
            _dbRef.child("rooms/${widget.roomNumber}/$sessionId").update({'terminated': true});
            setState(() {
              connected = false;
              waitingForUser = false;
              chatTerminated = true;
            });
          } else {
            setState(() {
              connected = false;
              waitingForUser = true;
              chatTerminated = false;
            });
          }
        } else {
          setState(() {
            connected = false;
            waitingForUser = true;
            chatTerminated = false;
          });
        }
      } else {
        setState(() {
          connected = false;
          waitingForUser = true;
          chatTerminated = false;
        });
      }
    });
  }

  void _sendMessage() {
    if (sessionId != null && _controller.text.trim().isNotEmpty) {
      _dbRef.child("rooms/${widget.roomNumber}/$sessionId/messages").push().set({
        "id": myId,
        "message": _controller.text,
        "timestamp": ServerValue.timestamp,
      });
    }
    _controller.clear();
    _trimMessages();
    Future.delayed(Duration(milliseconds: 100), () {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _trimMessages() async {
    if (sessionId == null) return;
    DatabaseReference messagesRef = _dbRef.child("rooms/${widget.roomNumber}/$sessionId/messages");
    DataSnapshot snapshot = await messagesRef.get();
    if (snapshot.exists) {
      Map<dynamic, dynamic> messages = snapshot.value as Map<dynamic, dynamic>;
      int messageCount = messages.length;
      if (messageCount > 30) {
        List<MapEntry<dynamic, dynamic>> entries = messages.entries.toList();
        entries.sort((a, b) => (a.value['timestamp'] as int).compareTo(b.value['timestamp'] as int));
        int messagesToDelete = messageCount - 30;
        for (int i = 0; i < messagesToDelete; i++) {
          String key = entries[i].key;
          messagesRef.child(key).remove();
        }
      }
    }
  }

  Future<void> _blockOpponent() async {
    String? opponentId;
    if (sessionId != null) {
      DataSnapshot snapshot = await _dbRef.child("rooms/${widget.roomNumber}/$sessionId/users").get();
      if (snapshot.exists) {
        Map<dynamic, dynamic> usersMap = snapshot.value as Map<dynamic, dynamic>;
        usersMap.forEach((key, value) {
          if (key != myId) {
            opponentId = key;
          }
        });
      }
    }
    if (opponentId != null) {
      await _dbRef.child("blocked").child(myId).child(opponentId!).set(true);
      await _dbRef.child("blocked").child(opponentId!).child(myId).set(true);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("상대방이 차단되었습니다.")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("차단할 상대를 찾지 못했습니다.")));
    }
    if (sessionId != null) {
      await _dbRef.child("rooms/${widget.roomNumber}/$sessionId")
          .update({'terminated': true});
    }
    setState(() {
      chatTerminated = true;
      connected = false;
      waitingForUser = false;
    });
  }

  Future<void> _leaveRoom() async {
    if (_hasLeftRoom || sessionId == null) return;

    await _dbRef.child("rooms/${widget.roomNumber}/$sessionId/users/$myId").onDisconnect().cancel();
    await _dbRef.child("rooms/${widget.roomNumber}/$sessionId/lastActivity").onDisconnect().cancel();
    await _dbRef.child("rooms/${widget.roomNumber}/$sessionId/terminated").onDisconnect().cancel();

    DatabaseReference sessionRef = _dbRef.child("rooms/${widget.roomNumber}/$sessionId");
    DatabaseReference sessionUsersRef = sessionRef.child("users");
    await sessionUsersRef.child(myId).remove();
    DataSnapshot snapshot = await sessionUsersRef.get();
    if (!snapshot.exists ||
        snapshot.value == null ||
        (snapshot.value is Map && (snapshot.value as Map).isEmpty)) {
      await sessionRef.remove();
    }
    _hasLeftRoom = true;
  }

  @override
  void dispose() {
    _leaveRoom();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildMessageList(Map<dynamic, dynamic> messagesMap) {
    List<Map<String, dynamic>> messagesList = messagesMap.entries.map((e) {
      return {
        "id": e.value["id"],
        "message": e.value["message"],
        "timestamp": e.value["timestamp"],
      };
    }).toList();
    messagesList.sort((a, b) => a["timestamp"].compareTo(b["timestamp"]));
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(8.0),
      itemCount: messagesList.length,
      itemBuilder: (context, index) {
        bool isMine = messagesList[index]["id"] == myId;
        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            padding: EdgeInsets.all(10),
            margin: EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: isMine ? Colors.blue[100] : Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(messagesList[index]["message"]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _leaveRoom();
        return true;
      },
      child: Scaffold(
        backgroundColor: _isWhite ? Colors.white : Colors.grey[800],
        appBar: AppBar(
          title: Text(
            widget.roomName,
          ),
          actions: [
            IconButton(
              icon: Icon(_isWhite ? Icons.wb_sunny : Icons.brightness_2),
              onPressed: () {
                setState(() {
                  _isWhite = !_isWhite;
                });
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                chatTerminated
                    ? "채팅이 종료되었습니다."
                    : (connected
                    ? "상대방과 연결되었습니다."
                    : (waitingForUser ? "상대를 기다리는 중..." : "방이 가득 찼습니다.")),
                style: TextStyle(
                  color: chatTerminated ? Colors.red : (connected ? Colors.green : Colors.red),
                  fontSize: 16,
                ),
              ),
            ),
            Expanded(
              child: sessionId == null
                  ? Center(child: CircularProgressIndicator())
                  : StreamBuilder<DatabaseEvent>(
                stream: _dbRef
                    .child("rooms/${widget.roomNumber}/$sessionId/messages")
                    .orderByChild("timestamp")
                    .limitToLast(30)
                    .onValue,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                    return Center(child: Text("메시지가 없습니다."));
                  }
                  Map<dynamic, dynamic> messagesMap =
                  snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });

                  return _buildMessageList(messagesMap);
                },
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 5.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      await _blockOpponent();
                    },
                    child: Text('차단하기'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _openReportDialog();
                    },
                    child: Text('신고하기'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      print('눌렀음 : $globalButtonPressCount');
                      await _onFindOpponentPressed();
                      if (sessionId != null) {
                        await _dbRef
                            .child("rooms/${widget.roomNumber}/$sessionId")
                            .update({'terminated': true});
                      }
                      await _leaveRoom();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RoomScreen(
                            roomName: widget.roomName,
                            roomNumber: widget.roomNumber,
                            isWhite: _isWhite,
                            myId: myId, // 생성된 사용자 아이디 사용
                          ),
                        ),
                      );
                    },
                    child: Text('상대찾기'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: '메시지를 입력하세요...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send),
                    onPressed: connected ? _sendMessage : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: BannerAdWidget(),
      ),
    );
  }
}
