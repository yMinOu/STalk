import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'home_screen.dart';
import 'rank_screen.dart';
import 'search_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      debugShowCheckedModeBanner: false, // DEBUG 배지 제거

      title: '서톡',
      theme: ThemeData(
        fontFamily: 'NanumSquareRoundB',

        primarySwatch: Colors.grey,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: MainPage(), // 최상위 화면에 바텀바를 포함한 MainPage 사용
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // 현재 선택된 탭 인덱스 (0: 랭킹, 1: 홈, 2: 검색)
  int _selectedIndex = 1;
  // 전체 배경색 토글을 위한 상태 변수
  bool _isWhite = true;
  // 사용자 아이디: HomeScreen, SearchScreen 등에서 사용할 예정
  String myId = '';

  @override
  void initState() {
    super.initState();
    _generateUserId();
  }

  // 여기서 사용자 아이디를 생성하거나 SharedPreferences 등으로 불러옵니다.
  void _generateUserId() {
    // 예시로 랜덤 숫자를 생성합니다.
    myId = Random().nextInt(100000).toString();
    setState(() {});
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      RankScreen(isWhite: _isWhite), // RankScreen은 별도 처리
      HomeScreen(isWhite: _isWhite, myId: myId),
      SearchScreen(isWhite: _isWhite, myId: myId),
    ];

    return Scaffold(
      backgroundColor: _isWhite ? Colors.white : Colors.grey[800],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          '서톡',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 26,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isWhite ? Icons.wb_sunny : Icons.brightness_2,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isWhite = !_isWhite;
              });
            },
          ),
        ],
      ),
      // IndexedStack을 사용하여 탭 전환 시 상태 유지
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: '랭킹',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: '검색',
          ),
        ],
      ),
    );
  }
}
