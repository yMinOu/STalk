import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'bannerAd.dart';
import 'rewardAd.dart'; // 리워드 광고 매니저 import

/// 무기(또는 항목) 데이터 모델: 투표 상태(voted) 추가
class WeaponItem {
  final String name;
  int count;
  bool voted;

  WeaponItem(this.name, {this.count = 0, this.voted = false});
}

/// 메달 데이터 모델
class MedalItem {
  final String name;
  int gold;
  int silver;
  int bronze;

  MedalItem({
    required this.name,
    this.gold = 0,
    this.silver = 0,
    this.bronze = 0,
  });
}

class RankScreen extends StatefulWidget {
  final bool isWhite;

  const RankScreen({
    Key? key,
    required this.isWhite,
  }) : super(key: key);

  @override
  State<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends State<RankScreen> {
  // 현재 선택된 탭 인덱스 (0:랭킹, 1:라플, 2:스나, 3:특총, 4:유저, 5:메달)
  int _selectedTabIndex = 0;

  // 탭에 표시될 텍스트 목록
  final List<String> _tabs = ['랭킹', '라플', '스나', '특총', '유저', '메달'];

  // 유저 페이지에 표시할 날짜 (Firebase 'userPageDate'에서 불러옴)
  String userPageDateText = 'Loading...';
  // 랭킹/라플/스나/특총 페이지에 표시할 날짜 (Firebase 'rankPageDate'에서 불러옴)
  String rankPageDateText = 'Loading...';

  // 월별 질문 (Firebase의 question 경로에서 읽어옴)
  String _monthlyQuestion = "";

  // 등록 가능한 최대 유저 수 (기본 100, Firebase 'maxUserCount'에서 불러옴)
  int maxUserCount = 20;

  // 라플, 스나, 특총은 고정 데이터
  final List<WeaponItem> _raffleItems = [
    WeaponItem('A.Crossbow'),
    WeaponItem('AK-103'),
    WeaponItem('AK-47'),
    WeaponItem('AK-47 Heavy'),
    WeaponItem('AK-47 Light'),
    WeaponItem('AK-47 Normal'),
    WeaponItem('ANR'),
    WeaponItem('CM901'),
    WeaponItem('DRT-6'),
    WeaponItem('FAMAS'),
    WeaponItem('G18 Rifle'),
    WeaponItem('G36K'),
    WeaponItem('GAL-1'),
    WeaponItem('HK416'),
    WeaponItem('K2'),
    WeaponItem('L85a1'),
    WeaponItem('M16'),
    WeaponItem('M4A1'),
    WeaponItem('NA-34'),
    WeaponItem('NA-94'),
    WeaponItem('RA-PDW'),
    WeaponItem('SCAR'),
    WeaponItem('SIG556'),
    WeaponItem('Stg44'),
    WeaponItem('TAVOR'),
    WeaponItem('UAR'),
    WeaponItem('Vz58'),
  ];

  final List<WeaponItem> _sniperItems = [
    WeaponItem('AWP'),
    WeaponItem('C.Crossbow'),
    WeaponItem('Dragunov'),
    WeaponItem('DSR-1'),
    WeaponItem('GSR-6'),
    WeaponItem('MSG90'),
    WeaponItem('MSR-200'),
    WeaponItem('Scout SR_69'),
    WeaponItem('SOCOM-K'),
    WeaponItem('SV-98'),
    WeaponItem('TRG-21'),
    WeaponItem('윈체스터'),
    WeaponItem('컴뱃보우'),
  ];

  final List<WeaponItem> _specialItems = [
    WeaponItem('Akimbo Pistols'),
    WeaponItem('Aks-74U'),
    WeaponItem('ASG-12'),
    WeaponItem('CZS-3'),
    WeaponItem('Dual MP7'),
    WeaponItem('K1'),
    WeaponItem('KRISS'),
    WeaponItem('KSG-12'),
    WeaponItem('M134 Minigun'),
    WeaponItem('M249'),
    WeaponItem('Mak-11'),
    WeaponItem('Mak-12'),
    WeaponItem('MG43'),
    WeaponItem('MP5'),
    WeaponItem('MP7'),
    WeaponItem('P90'),
    WeaponItem('SG-12'),
    WeaponItem('SG870'),
    WeaponItem('Shield'),
    WeaponItem('SMG U101'),
    WeaponItem('Winchester 1880'),
  ];

  // 유저 페이지 데이터: Firebase 'votes/user' 데이터를 사용 (동적으로 불러옴)
  List<WeaponItem> _userItems = [];

  // 메달 페이지 데이터: Firebase 'medals' 데이터를 사용
  List<MedalItem> _medalItems = [];

  @override
  void initState() {
    super.initState();
    _setupFirebaseListeners();
    _updateMonthlyQuestion();
    _updateUserPageDate(); // 유저 페이지 날짜 업데이트
    _updateRankPageDate(); // 랭킹/라플/스나/특총 페이지 날짜 업데이트
    _updateMaxUserCount(); // 최대 등록 인원 업데이트
    _loadVotedItems();
    _updateMedalData(); // 메달 데이터 업데이트

    // 리워드 광고 미리 로드
    RewardAdManager().loadRewardAd();
  }

  /// Firebase에서 데이터 리스닝 설정
  void _setupFirebaseListeners() {
    _updateWeaponCounts('raffle', _raffleItems);
    _updateWeaponCounts('sniper', _sniperItems);
    _updateWeaponCounts('special', _specialItems);
    _updateUserData();
  }

  // 일반 카테고리 업데이트
  void _updateWeaponCounts(String category, List<WeaponItem> items) {
    final ref = FirebaseDatabase.instance.ref('votes/$category');
    ref.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          // 기존 항목 업데이트
          for (var item in items) {
            if (data.containsKey(item.name)) {
              item.count = data[item.name] as int;
            } else {
              item.count = 0;
            }
          }
          // Firebase에만 있는 새 항목을 리스트에 추가
          data.forEach((key, value) {
            if (items.every((item) => item.name != key)) {
              items.add(WeaponItem(key, count: value as int));
            }
          });
        });
      }
    });
  }


  // 유저 데이터 업데이트: Firebase 'votes/user' 데이터 사용
  void _updateUserData() {
    final ref = FirebaseDatabase.instance.ref('votes/user');
    ref.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        List<WeaponItem> updatedList = [];
        data.forEach((key, value) {
          bool voted = false;
          for (var existing in _userItems) {
            if (existing.name == key) {
              voted = existing.voted;
              break;
            }
          }
          updatedList.add(WeaponItem(key, count: value as int, voted: voted));
        });
        setState(() {
          _userItems
            ..clear()
            ..addAll(updatedList);
        });
      }
    });
  }

  // 메달 데이터 업데이트: Firebase 'medals' 경로에서 데이터 불러옴
  void _updateMedalData() {
    final ref = FirebaseDatabase.instance.ref('medals');
    ref.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        List<MedalItem> updatedList = [];
        data.forEach((key, value) {
          updatedList.add(MedalItem(
            name: key.toString(),
            gold: (value['gold'] ?? 0) as int,
            silver: (value['silver'] ?? 0) as int,
            bronze: (value['bronze'] ?? 0) as int,
          ));
        });
        setState(() {
          _medalItems = updatedList;
        });
      }
    });
  }

  // Firebase의 'question' 경로에서 월별 질문 텍스트를 읽어옴
  void _updateMonthlyQuestion() {
    final ref = FirebaseDatabase.instance.ref('question');
    ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null) {
        setState(() {
          _monthlyQuestion = data.toString();
        });
      }
    });
  }

  // Firebase 'userPageDate' 경로에서 유저 페이지 날짜를 읽어옴
  void _updateUserPageDate() {
    final ref = FirebaseDatabase.instance.ref('userPageDate');
    ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null) {
        setState(() {
          userPageDateText = data.toString();
        });
      }
    });
  }

  // Firebase 'rankPageDate' 경로에서 랭킹/라플/스나/특총 페이지 날짜를 읽어옴
  void _updateRankPageDate() {
    final ref = FirebaseDatabase.instance.ref('rankPageDate');
    ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null) {
        setState(() {
          rankPageDateText = data.toString();
        });
      }
    });
  }

  // Firebase 'maxUserCount' 경로에서 최대 등록 인원 값을 읽어옴
  void _updateMaxUserCount() {
    final ref = FirebaseDatabase.instance.ref('maxUserCount');
    ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null) {
        setState(() {
          maxUserCount = int.tryParse(data.toString()) ?? 100;
        });
      }
    });
  }

  // SharedPreferences를 사용해 로컬에 투표한 항목을 저장/불러오기
  Future<void> _loadVotedItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int currentMonth = DateTime.now().month;
    int? savedMonth = prefs.getInt('lastResetMonth');
    if (savedMonth == null || savedMonth != currentMonth) {
      await prefs.remove('votedItems');
      await prefs.setInt('lastResetMonth', currentMonth);
    }
    List<String>? votedList = prefs.getStringList('votedItems');
    if (votedList != null) {
      setState(() {
        for (var item in _raffleItems) {
          if (votedList.contains(item.name)) item.voted = true;
        }
        for (var item in _sniperItems) {
          if (votedList.contains(item.name)) item.voted = true;
        }
        for (var item in _specialItems) {
          if (votedList.contains(item.name)) item.voted = true;
        }
        for (var item in _userItems) {
          if (votedList.contains(item.name)) item.voted = true;
        }
      });
    }
  }

  Future<void> _updateVotedItemsInPrefs(String itemName, bool voted) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> votedList = prefs.getStringList('votedItems') ?? [];
    if (voted) {
      if (!votedList.contains(itemName)) {
        votedList.add(itemName);
      }
    } else {
      votedList.remove(itemName);
    }
    await prefs.setStringList('votedItems', votedList);
  }

  // 탭 선택 함수
  void _onTabSelected(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
  }

  /// 투표 토글: 빈 별이면 투표(노란 별, count 증가), 노란 별이면 취소(빈 별, count 감소)
  void _toggleVote(WeaponItem item, String category) {
    final ref = FirebaseDatabase.instance.ref('votes/$category/${item.name}');
    setState(() {
      if (item.voted) {
        item.count--;
        item.voted = false;
      } else {
        item.count++;
        item.voted = true;
      }
      ref.set(item.count);
      _updateVotedItemsInPrefs(item.name, item.voted);
    });
  }

  // 전달된 리스트를 vote count 기준 내림차순 정렬하여 상위 3개 리턴 (랭킹 페이지용)
  List<WeaponItem> _getTop3(List<WeaponItem> items) {
    List<WeaponItem> sorted = [...items];
    sorted.sort((a, b) => b.count.compareTo(a.count));
    return sorted.take(3).toList();
  }

  // URL 열기 (유저 페이지의 cafe 이미지 클릭 시)
  Future<void> _launchCafeURL() async {
    const url = 'https://cafe.naver.com/attackgirl0';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  // 등록 버튼을 눌렀을 때 호출: 리워드 광고 보여주고, 광고 완료 시 닉네임 등록 다이얼로그 표시
  void _onRegisterButtonPressed() {
    RewardAdManager().showRewardAd(
      onUserEarnedReward: () {
        _showNicknameDialog();
      },
    );
  }

  // 닉네임 등록 다이얼로그 표시
  void _showNicknameDialog() {
    TextEditingController nicknameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('닉네임 등록'),
          content: TextField(
            controller: nicknameController,
            decoration: const InputDecoration(
              hintText: '닉네임을 입력하세요',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                String nickname = nicknameController.text.trim();
                if (nickname.isNotEmpty) {
                  // 한글, 영어, 숫자만 허용하는 정규식 체크
                  if (!RegExp(r'^[a-zA-Z0-9가-힣]+$').hasMatch(nickname)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('특수문자는 사용불가합니다. 한글, 숫자, 영어만 사용 가능합니다.'),
                      ),
                    );
                    return;
                  }

                  // Firebase에서 최신 maxUserCount 값을 즉시 읽어옴
                  final snapshotMax = await FirebaseDatabase.instance
                      .ref('maxUserCount')
                      .get();
                  int latestMaxUserCount =
                      int.tryParse(snapshotMax.value.toString()) ?? 100;

                  // Firebase에서 현재 등록된 유저 수를 직접 조회
                  final snapshotUsers = await FirebaseDatabase.instance
                      .ref('votes/user')
                      .get();
                  int currentUserCount = 0;
                  if (snapshotUsers.value != null) {
                    Map<dynamic, dynamic> users =
                    snapshotUsers.value as Map<dynamic, dynamic>;
                    currentUserCount = users.length;
                  }

                  // 현재 등록된 유저 수와 최신 maxUserCount를 비교
                  if (currentUserCount >= latestMaxUserCount) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('등록 가능한 수가 초과되었습니다.'),
                      ),
                    );
                    return;
                  }

                  // Firebase 'votes/user'에 닉네임을 등록 (초기값 0)
                  await FirebaseDatabase.instance
                      .ref('votes/user')
                      .child(nickname)
                      .set(0);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('등록'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isWhite ? Colors.white : Colors.grey[800];
    final defaultTextColor = widget.isWhite ? Colors.black : Colors.white;
    final appBarColor = widget.isWhite ? Colors.grey[300] : Colors.grey[700];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // (1) 상단 탭 바: 랭킹, 라플, 스나, 특총, 유저, 메달
            Container(
              color: appBarColor,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_tabs.length, (index) {
                  final bool isSelected = (index == _selectedTabIndex);
                  final textColor = isSelected ? Colors.red[800] : defaultTextColor;
                  return GestureDetector(
                    onTap: () => _onTabSelected(index),
                    child: Text(
                      _tabs[index],
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }),
              ),
            ),
            // (2) 날짜 텍스트 및 구분선 (메달 페이지 제외)
            if (_selectedTabIndex != 5)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  // 유저 페이지(인덱스 4)는 userPageDateText, 그 외(랭킹, 라플, 스나, 특총)는 rankPageDateText 사용
                  _selectedTabIndex == 4 ? userPageDateText : rankPageDateText,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Divider(
              color: widget.isWhite ? Colors.grey : Colors.grey[400],
              height: 1,
            ),
            // (3) 선택된 탭별 화면
            Expanded(
              child: _buildSelectedTab(defaultTextColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTab(Color defaultTextColor) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildRankingPage(defaultTextColor);
      case 1:
        return _buildWeaponList(_raffleItems, 'raffle', defaultTextColor);
      case 2:
        return _buildWeaponList(_sniperItems, 'sniper', defaultTextColor);
      case 3:
        return _buildWeaponList(_specialItems, 'special', defaultTextColor);
      case 4:
        return _buildUserPage(defaultTextColor);
      case 5:
        return _buildMedalPage(defaultTextColor);
      default:
        return Container();
    }
  }

  // 랭킹 페이지: 각 카테고리 상위 3개 읽기 전용 (투표 기능 없음)
  // 유저 Top 3 및 질문 영역 추가
  Widget _buildRankingPage(Color defaultTextColor) {
    final topRaffle = _getTop3(_raffleItems);
    final topSniper = _getTop3(_sniperItems);
    final topSpecial = _getTop3(_specialItems);
    final topUser = _getTop3(_userItems);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            const SizedBox(height: 5),
            _buildRankingSection('라플 Top 3', topRaffle, defaultTextColor),
            _buildRankingSection('스나 Top 3', topSniper, defaultTextColor),
            BannerAdWidget(),
            _buildRankingSection('특총 Top 3', topSpecial, defaultTextColor),
            const SizedBox(height: 5),
            // 질문 영역 (어두운 회색 배경, 흰 텍스트)
            Container(
              width: double.infinity,
              color: Colors.grey[800],
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.centerLeft,
              child: Text(
                _monthlyQuestion,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildRankingSection('유저 Top 3', topUser, defaultTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingSection(String title, List<WeaponItem> items, Color defaultTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: defaultTextColor),
        ),
        const SizedBox(height: 8),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return ListTile(
            leading: Text(
              '${index + 1}.',
              style: TextStyle(
                color: defaultTextColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            title: Text(item.name, style: TextStyle(color: defaultTextColor)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: Colors.yellow),
                const SizedBox(width: 4),
                Text('${item.count}', style: TextStyle(color: defaultTextColor, fontSize: 16)),
              ],
            ),
          );
        }).toList(),
        const Divider(),
      ],
    );
  }

  // 라플, 스나, 특총 페이지: 기존 _buildWeaponList와 동일
  Widget _buildWeaponList(List<WeaponItem> items, String category, Color defaultTextColor) {
    List<WeaponItem> sortedItems = [...items];
    sortedItems.sort((a, b) => b.count.compareTo(a.count));
    int adFrequency = 10;
    int totalItemCount = sortedItems.length + (sortedItems.length ~/ adFrequency);

    return ListView.builder(
      itemCount: totalItemCount,
      itemBuilder: (context, index) {
        if ((index + 1) % (adFrequency + 1) == 0) {
          return BannerAdWidget();
        } else {
          int dataIndex = index - (index ~/ (adFrequency + 1));
          final weapon = sortedItems[dataIndex];
          return ListTile(
            leading: Text(
              '${dataIndex + 1}.',
              style: TextStyle(
                color: defaultTextColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            title: Text(weapon.name, style: TextStyle(color: defaultTextColor)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    weapon.voted ? Icons.star : Icons.star_border,
                    color: weapon.voted ? Colors.yellow : defaultTextColor,
                  ),
                  onPressed: () => _toggleVote(weapon, category),
                ),
                const SizedBox(width: 4),
                Text('${weapon.count}', style: TextStyle(color: defaultTextColor, fontSize: 16)),
              ],
            ),
          );
        }
      },
    );
  }

  // 유저 페이지: 질문 영역과 카페 버튼, 등록 버튼 오버레이
  Widget _buildUserPage(Color defaultTextColor) {
    return Stack(
      children: [
        Column(
          children: [
            // 월별 질문 영역: 어두운 회색 배경, 흰 텍스트
            Container(
              width: double.infinity,
              color: Colors.grey[800],
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.centerLeft,
              child: Text(
                _monthlyQuestion,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: _buildWeaponList(_userItems, 'user', defaultTextColor),
              ),
            ),
          ],
        ),
        // 하단에 등록 버튼과 카페 버튼 (등록 버튼 왼쪽에 위치)
        Positioned(
          bottom: 16,
          right: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 등록 버튼: 크기 width 50, height 50
              SizedBox(
                width: 50,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8), // 모서리 둥글게 설정
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: _onRegisterButtonPressed,
                  child: const Text(
                    '등록',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _launchCafeURL,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/cafe.png',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 메달 페이지: 메달 정보 표시 (날짜는 표시하지 않음)
  Widget _buildMedalPage(Color defaultTextColor) {
    List<MedalItem> sortedMedals = [..._medalItems];
    sortedMedals.sort((a, b) {
      int scoreA = a.gold * 3 + a.silver * 2 + a.bronze;
      int scoreB = b.gold * 3 + b.silver * 2 + b.bronze;
      return scoreB.compareTo(scoreA);
    });
    return ListView.builder(
      itemCount: sortedMedals.length,
      itemBuilder: (context, index) {
        final medal = sortedMedals[index];
        return ListTile(
          leading: Text(
            '${index + 1}.',
            style: TextStyle(
              color: defaultTextColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          title: Text(medal.name, style: TextStyle(color: defaultTextColor)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text('${medal.gold}', style: TextStyle(color: defaultTextColor, fontSize: 14)),
                ],
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.grey, size: 20),
                  const SizedBox(width: 4),
                  Text('${medal.silver}', style: TextStyle(color: defaultTextColor, fontSize: 14)),
                ],
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.brown, size: 20),
                  const SizedBox(width: 4),
                  Text('${medal.bronze}', style: TextStyle(color: defaultTextColor, fontSize: 14)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
