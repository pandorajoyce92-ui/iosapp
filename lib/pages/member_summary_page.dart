import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/config.dart';
import '../core/http_client.dart';
import '../models/summary_card_data.dart';
import '../widgets/summary_card_widget.dart';

class MemberSummaryPage extends StatefulWidget {
  final int roomid;
  final int targetUid;
  final String targetNickname;

  const MemberSummaryPage({
    super.key,
    required this.roomid,
    required this.targetUid,
    required this.targetNickname,
  });

  @override
  State<MemberSummaryPage> createState() => _MemberSummaryPageState();
}

class _MemberSummaryPageState extends State<MemberSummaryPage> {
  bool _loading = true;
  List<SummaryCardData> _cards = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.redlog}&op=get_card_summary&roomid=${widget.roomid}&target_uid=${widget.targetUid}',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final result = Map<String, dynamic>.from(data['result']);
        final List rawList = result['child_cards'] ?? [];
        _cards = rawList.map((e) => SummaryCardData.fromJson(Map<String, dynamic>.from(e))).toList();
      }
    } catch (e) {
      debugPrint('❌ [MemberSummaryPage] $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.targetNickname} 的下属收益'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cards.isEmpty
              ? const Center(child: Text('暂无下属数据'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _cards.length,
                  itemBuilder: (ctx, i) {
                    final card = _cards[i];
                    return SummaryCardWidget(
                      data: card,
                      isCurrentUser: false,
                      onViewSubordinate: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MemberSummaryPage(
                              roomid: widget.roomid,
                              targetUid: card.uid,
                              targetNickname: card.nickname,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}