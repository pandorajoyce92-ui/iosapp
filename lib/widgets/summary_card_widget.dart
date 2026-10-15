import 'package:flutter/material.dart';
import '../models/summary_card_data.dart';

class SummaryCardWidget extends StatelessWidget {
  final SummaryCardData data;
  final bool isCurrentUser;
  final VoidCallback? onViewSubordinate;

  const SummaryCardWidget({
    super.key,
    required this.data,
    this.isCurrentUser = false,
    this.onViewSubordinate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xF2FFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：头像 + 昵称 + 徽章 + 查看下属收益
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blueAccent,
                backgroundImage: data.avatar.isNotEmpty ? NetworkImage(data.avatar) : null,
                child: data.avatar.isEmpty
                    ? Text(
                        data.nickname.isNotEmpty ? data.nickname[0] : '?',
                        style: const TextStyle(color: Colors.white),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        data.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_buildRoleTag() != null) ...[
                      const SizedBox(width: 6),
                      _buildRoleTag()!,
                    ],
                  ],
                ),
              ),
              if (data.hasViewSubordinate && !isCurrentUser)
                GestureDetector(
                  onTap: onViewSubordinate,
                  child: Row(
                    children: const [
                      Text('查看下属收益',
                          style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
                      Icon(Icons.chevron_right, size: 16, color: Color(0xFF999999)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 数据网格（每行3个）
          _buildDataGrid(),

          const SizedBox(height: 12),

          // 公式区
          Text(
            '发包流水(${_fmt(data.sendFlow)})+抢包流水(${_fmt(data.getFlow)})=${_fmt(data.sendFlow + data.getFlow)}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF007AFF)),
          ),
          const SizedBox(height: 4),
          if (!data.isPlayer && data.profitLabel.isNotEmpty)
            Text(
              '${data.profitLabel}：${_fmt(data.actualProfit)} 元',
              style: const TextStyle(fontSize: 13, color: Color(0xFF007AFF)),
            ),

          const SizedBox(height: 12),

          // 下级汇总
          if (!data.isPlayer) ...[
            _buildSummaryRow('下级发红包总计', data.downlineSummary['total_send_flow'] ?? 0),
            _buildSummaryRow('下级抢红包总计', data.downlineSummary['total_get_flow'] ?? 0),
            _buildSummaryRow('下级发返奖红包总计', data.downlineSummary['total_boom_return'] ?? 0),
            _buildSummaryRow('下级总充值', data.downlineSummary['total_recharge'] ?? 0, isRed: true),
            _buildSummaryRow('下级总提现', data.downlineSummary['total_withdraw'] ?? 0, isRed: true),
            _buildSummaryRow('下级盈亏', data.downlineSummary['total_win_loss'] ?? 0, isRed: true),
            _buildSummaryRow('下级返福利盈亏', data.downlineSummary['total_welfare'] ?? 0, isRed: true),
            const Divider(height: 24),
          ] else ...[
            Text('进群方式：${data.joinWay}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF999999))),
            Text('所属股东：${data.belongTo}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF999999))),
          ],

          // 比例显示
          if (!data.isPlayer) ...[
            if (data.roleType == 'shareholder') ...[
              // 股东：只显示分红比例
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('分红比例',
                      style: TextStyle(fontSize: 13, color: Color(0xFF333333))),
                  Text('${data.ratio.toStringAsFixed(2)}%',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF333333))),
                ],
              ),
            ] else if (data.roleType.startsWith('agent_')) ...[
              // 代理：发包 + 抢包两行
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('流水比例',
                      style: TextStyle(fontSize: 13, color: Color(0xFF333333))),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('发包流水比例：${data.sendRatio.toStringAsFixed(2)}%',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF333333))),
                      const SizedBox(height: 2),
                      Text('抢包流水比例：${data.grabRatio.toStringAsFixed(2)}%',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF333333))),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ★★★ 新增：身份徽章（和 shareholder_apply_page.dart 保持一致）★★★
  Widget? _buildRoleTag() {
    final rt = data.roleType;
    if (rt == 'owner') {
      return _tag('群主', const Color(0xFFE94848));
    }
    if (rt == 'shareholder') {
      return _tag('股东', const Color(0xFF8B5CF6));
    }
    if (rt == 'agent_1') {
      return _tag('一级代理', const Color(0xFF3B82F6));
    }
    if (rt == 'agent_2') {
      return _tag('二级代理', const Color(0xFF06B6D4));
    }
    if (rt == 'agent_3') {
      return _tag('三级代理', const Color(0xFF10B981));
    }
    if (rt == 'player') {
      return _tag('玩家', const Color(0xFF9CA3AF));
    }
    return null;
  }

  Widget _tag(String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // 每行 3 个，宽度自适应
  Widget _buildDataGrid() {
    final items = <MapEntry<String, double>>[
      MapEntry('充值', data.recharge),
      MapEntry('发包流水', data.sendFlow),
      MapEntry('提现', data.withdraw),
      MapEntry('所抢红包', data.getFlow),
      MapEntry('派发福利', data.welfare),
      MapEntry('抢包中雷', data.boomDeduct),
      MapEntry('发包出雷返', data.boomReturn),
      MapEntry('盈亏', data.winLoss),
      MapEntry('总余额', data.balance),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 8.0;
        final double itemWidth = (constraints.maxWidth - spacing * 2) / 3;

        return Wrap(
          spacing: spacing,
          runSpacing: 12,
          children: items.map((entry) {
            return SizedBox(
              width: itemWidth,
              child: _buildGridItem(entry.key, entry.value),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildGridItem(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
        const SizedBox(height: 2),
        Text(
          _fmt(value),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111111),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF999999))),
          Text(
            _fmt(value),
            style: TextStyle(
              fontSize: 13,
              color: isRed ? const Color(0xFFE94848) : const Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(2);
}