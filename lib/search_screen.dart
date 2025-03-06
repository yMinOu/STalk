import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // digitsOnly를 위해 필요
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'bannerAd.dart';

enum SearchState { initial, notFound, pending, found }

class SearchScreen extends StatefulWidget {
  final bool isWhite;
  final String myId; // main.dart에서 전달된 user_id

  const SearchScreen({Key? key, required this.isWhite, required this.myId})
      : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  SearchState _screenState = SearchState.initial;
  late Color defaultTextColor;
  String? _searchedNumber;
  String _foundLink = '';
  // 라디오 버튼 선택 종류를 저장할 변수 추가
  String? _selectedOption;

  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  // 새로운 검거 시간 컨트롤러 (기본값 "00:00:00")
  final TextEditingController _timeController = TextEditingController();

  // numbers 경로에 데이터를 저장합니다.
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("numbers");

  /// 검색 로직
  Future<void> _searchNumber(String number) async {
    final query = _dbRef.orderByChild('number').equalTo(number);
    final snapshot = await query.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final firstKey = data.keys.first;
      final record = data[firstKey] as Map<dynamic, dynamic>;
      _searchedNumber = number;
      _foundLink = record['link'] ?? '';
      _selectedOption = record['selectedOption'] ?? '';  // 추가된 부분
      if (record['status'] == true) {
        setState(() {
          _screenState = SearchState.found;
        });
      } else {
        setState(() {
          _screenState = SearchState.pending;
        });
      }
    } else {
      _searchedNumber = number;
      _linkController.clear();
      setState(() {
        _screenState = SearchState.notFound;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    defaultTextColor = widget.isWhite ? Colors.black : Colors.white;
  }

  /// 미등록 번호 등록 로직
  Future<void> _registerNumber() async {
    if (_searchedNumber == null || _searchedNumber!.isEmpty) return;
    final link = _linkController.text.trim();
    final time = _timeController.text.trim();
    // 링크, 시간, 그리고 라디오 선택 모두 필수 입력
    if (link.isEmpty || time.isEmpty || _selectedOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("모두 작성해 주세요")),
      );
      return;
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _dbRef.child(timestamp.toString());
    await ref.set({
      'number': _searchedNumber!,
      'link': link,
      'time': time, // 검거 시간 데이터 추가
      'selectedOption': _selectedOption, // 라디오 버튼 선택 값 저장
      'status': false, // 등록 대기중 종류
      'timestamp': timestamp,
      'userId': widget.myId,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("병영번호 $_searchedNumber가 등록 대기중입니다.")),
    );
    setState(() {
      _screenState = SearchState.initial;
      // 등록 후 라디오 선택 초기화
      _selectedOption = null;
    });
  }

  /// 목록 버튼: 기본 화면으로 전환
  void _goToInitialScreen() {
    setState(() {
      _screenState = SearchState.initial;
      _searchedNumber = null;
      _foundLink = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isWhite ? Colors.white : Colors.grey[800];

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50),
              Container(
                width: double.infinity,
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    text: '검색할 ',
                    style: TextStyle(color: widget.isWhite ? Colors.black : Colors.white, fontSize: 24),
                    children: [
                      TextSpan(
                        text: '병영번호',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: '를 입력하세요',
                        style: TextStyle(color: widget.isWhite ? Colors.black : Colors.white, fontSize: 24),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) {
                        // 새로 입력하면 검색 결과 초기화
                        if (value.isNotEmpty) {
                          setState(() {
                            _searchedNumber = null;
                            _foundLink = '';
                            _screenState = SearchState.initial;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey,
                        hintText: '숫자를 입력하세요',
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: Colors.red, width: 2.0),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final input = _searchController.text.trim();
                      if (input.isNotEmpty) {
                        _searchNumber(input);
                        _searchController.clear();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: const Text('검색'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildBodyByState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBodyByState() {
    switch (_screenState) {
      case SearchState.initial:
        return _buildInitialView();
      case SearchState.notFound:
        return _buildNotFoundView();
      case SearchState.pending:
        return _buildPendingView();
      case SearchState.found:
        return _buildFoundView();
    }
  }

  /// 기본 화면: 등록된 병영 번호 개수, 배너 광고, 최근 등록 6개
  Widget _buildInitialView() {
    return StreamBuilder<DatabaseEvent>(
      stream: _dbRef.orderByChild('timestamp').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<dynamic> records = [];
        for (var child in snapshot.data!.snapshot.children) {
          final value = child.value as Map<dynamic, dynamic>;
          records.add(value);
        }
        final approvedNumbersList =
        records.where((record) => record['status'] == true).toList();
        final totalApprovedCount = approvedNumbersList.length;
        final recentApprovedNumbers = approvedNumbersList.reversed.take(6).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '등록된 병영번호 : $totalApprovedCount개',
              style: TextStyle(color: widget.isWhite ? Colors.black : Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 16),
            //BannerAdWidget(),
            const SizedBox(height: 16),
            Text(
              '최근 등록 병영번호',
              style: TextStyle(color: widget.isWhite ? Colors.black : Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentApprovedNumbers.length,
              itemBuilder: (context, index) {
                final record = recentApprovedNumbers[index] as Map;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _searchedNumber = record['number'].toString();
                      _foundLink = record['link'] ?? '';
                      _selectedOption = record['selectedOption'] ?? '';
                      _screenState = record['status'] == true ? SearchState.found : SearchState.pending;
                    });
                  },
                  child: ListTile(
                    title: Text(
                      record['number'].toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// 미등록 병영 번호 화면: 입력한 번호와 링크, 검거 시간 입력 필드, 라디오 버튼, 등록/목록 버튼
  Widget _buildNotFoundView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          color: widget.isWhite ? Colors.black12 : Colors.black45,
          padding: const EdgeInsets.all(8.0),
          child: Text(
            '미등록 병영번호',
            style: TextStyle(
              color: widget.isWhite ? Colors.black : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            color: Colors.grey[300],
          ),
          child: Column(
            children: [
              // 병영번호 출력
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      child: const Text(
                        '병영번호',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _searchedNumber ?? '',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
              // 증거 영상 링크 입력
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      child: const Text(
                        '증거 영상 링크',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _linkController,
                        decoration: const InputDecoration(
                          hintText: '링크를 입력하세요',
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 2.0),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // 검거 시간 입력 필드 (라벨을 텍스트필드 위로 정렬)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: const Text(
                        '검거 시간',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _timeController,
                        maxLength: 8,
                        decoration: const InputDecoration(
                          hintText: '00:00:00',
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 2.0),
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // 라디오 버튼: 'SP사기', '검거완료', '판독신청'
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      child: const Text(
                        '카테고리 선택',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text('SP사기'),
                          value: 'SP사기',
                          groupValue: _selectedOption,
                          activeColor: Colors.red,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onChanged: (value) {
                            setState(() {
                              _selectedOption = value;
                            });
                          },
                        ),
                        RadioListTile<String>(
                          title: const Text('검거완료'),
                          value: '검거완료',
                          groupValue: _selectedOption,
                          activeColor: Colors.red,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onChanged: (value) {
                            setState(() {
                              _selectedOption = value;
                            });
                          },
                        ),
                        RadioListTile<String>(
                          title: const Text('판독신청'),
                          value: '판독신청',
                          groupValue: _selectedOption,
                          activeColor: Colors.red,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onChanged: (value) {
                            setState(() {
                              _selectedOption = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _registerNumber,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[800],
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              child: const Text('등록'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _goToInitialScreen,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              child: const Text('목록'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 페이지 하단에 배너 광고 추가
        //BannerAdWidget(),
      ],
    );
  }

  // 등록 대기중 페이지 (_buildPendingView)
  Widget _buildPendingView() {
    return Column(
      children: [
        const Center(
          child: Text(
            '등록 대기중입니다.',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: _goToInitialScreen,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: const Text('목록'),
          ),
        ),
        const SizedBox(height: 16),
        // 페이지 하단에 배너 광고 추가
        //BannerAdWidget(),
      ],
    );
  }

  // 등록된 병영번호 페이지 (_buildFoundView)
  Widget _buildFoundView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_foundLink.isNotEmpty) ...[
                Text(
                  _searchedNumber ?? '',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '증거 영상 링크',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final url = _foundLink;
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  child: Text(
                    _foundLink.isEmpty ? '링크가 없습니다.' : _foundLink,
                    style: const TextStyle(
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '카테고리: ${_selectedOption ?? ""}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ] else ...[
                const Text(
                  '등록 대기중입니다.',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ]
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: _goToInitialScreen,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: const Text('목록'),
          ),
        ),
        const SizedBox(height: 16),
        // 페이지 하단에 배너 광고 추가
        //BannerAdWidget(),
      ],
    );
  }
}

class RegisteredNumberScreen extends StatelessWidget {
  final Map record;
  const RegisteredNumberScreen({Key? key, required this.record}) : super(key: key);

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 선택된 옵션 값을 읽어옵니다.
    final selectedOption = record['selectedOption'] ?? '선택없음';

    return Scaffold(
      appBar: AppBar(
        title: Text("병영번호 등록 정보"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record['number'].toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: record['status'] == true ? Colors.red : Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '증거 영상 링크',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            record['link'] != null && record['link'].toString().isNotEmpty
                ? GestureDetector(
              onTap: () => _launchURL(record['link']),
              child: Text(
                record['link'].toString(),
                style: const TextStyle(
                  fontSize: 16,
                  decoration: TextDecoration.underline,
                  color: Colors.blue,
                ),
              ),
            )
                : const Text('링크가 없습니다.', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            // 선택한 라디오 버튼(상태) 값을 보여주는 부분 추가
            Text(
              '카테고리: $selectedOption',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: const Text('목록'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
