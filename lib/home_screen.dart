import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

import 'AutoSlidingBanner.dart';
import 'bannerAd.dart';
import 'room_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool isWhite;
  final String myId; // main.dart에서 생성한 사용자 아이디

  const HomeScreen({Key? key, required this.isWhite, required this.myId})
      : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> roomNames = ["3보급", "A보급", "대룰, 랭크전"];
  bool isBanned = false;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _checkBannedStatus();
  }

  Future<void> _checkBannedStatus() async {
    DataSnapshot bannedSnapshot =
    await _dbRef.child("bannedUsers").child(widget.myId).get();
    if (bannedSnapshot.exists && bannedSnapshot.value == true) {
      setState(() {
        isBanned = true;
      });
    }
  }

  void _showBannedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("사용자는 일시 정지되었습니다.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isWhite ? Colors.white : Colors.grey[800],
      body: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AutoSlidingBanner(), // 5초마다 바뀌는 배너
              Expanded(
                child: ListView.builder(
                  itemCount: roomNames.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: SizedBox(
                          width: 250,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: () {
                              if (isBanned) {
                                _showBannedMessage();
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RoomScreen(
                                    roomName: roomNames[index],
                                    roomNumber: index + 1,
                                    isWhite: widget.isWhite,
                                    myId: widget.myId, // 전달받은 사용자 아이디 사용
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              fixedSize: const Size(60, 60),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              roomNames[index],
                              style: const TextStyle(
                                fontSize: 20,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            //child: BannerAdWidget(), // 하단 고정 배너 광고
          ),
        ],
      ),
    );
  }
}
