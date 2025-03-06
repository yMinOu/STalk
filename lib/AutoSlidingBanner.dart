// AutoSlidingBanner.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AutoSlidingBanner extends StatefulWidget {
  @override
  _AutoSlidingBannerState createState() => _AutoSlidingBannerState();
}

class _AutoSlidingBannerState extends State<AutoSlidingBanner> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<String> _images = [];

  @override
  void initState() {
    super.initState();
    // 이미지 데이터 로드 이후 타이머를 시작하도록 구현
  }

  void _startAutoSlide() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (_images.isNotEmpty) {
        _currentPage = (_currentPage < _images.length - 1) ? _currentPage + 1 : 0;
        _pageController.animateToPage(
          _currentPage,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: StreamBuilder<DatabaseEvent>(
        stream: _dbRef.child('bannerImages').onValue,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            var data = snapshot.data!.snapshot.value;
            if (data is List) {
              _images = data.where((element) => element != null)
                  .map((element) => element.toString())
                  .toList();
            } else if (data is Map) {
              _images = data.values.map((value) => value.toString()).toList();
            }
            if (_timer == null || !_timer!.isActive) {
              _startAutoSlide();
            }
            return PageView.builder(
              controller: _pageController,
              itemCount: _images.length,
              itemBuilder: (context, index) {
                return Image.network(
                  _images[index],
                  fit: BoxFit.fitHeight,
                );
              },
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
