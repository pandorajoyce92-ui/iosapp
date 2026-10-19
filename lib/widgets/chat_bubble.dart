import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../core/app_cache_manager.dart';

import '../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage msg;
  final int myUid;
  final String myAvatar;
  final String friendAvatar;
  final void Function(ChatMessage msg)? onTapTransfer;
  final void Function(ChatMessage msg)? onTapRecharge;
  final void Function(ChatMessage msg)? onTapWithdraw;
  final void Function(String url)? onTapImage;

  const ChatBubble({
    super.key,
    required this.msg,
    required this.myUid,
    required this.myAvatar,
    required this.friendAvatar,
    this.onTapTransfer,
    this.onTapRecharge,
    this.onTapWithdraw,
    this.onTapImage,
  });

  @override
  Widget build(BuildContext context) {
    final isSelf = msg.uid == myUid;

    if (msg.type == 3) return _buildApplyCard(context, isSelf, isRecharge: true);
    if (msg.type == 4) return _buildApplyCard(context, isSelf, isRecharge: false);
    if (msg.type == 5) return _buildLhcTransferCard(context, isSelf);
    if (msg.type == 0) return _buildTransferCard(context, isSelf);

    return _buildNormalBubble(context, isSelf);
  }

            Widget _buildAvatar(String url) {
              if (url.isEmpty) {
                return Container(
                  width: 44, height: 44,
                  color: const Color(0xFFF0ECFF),
                  alignment: Alignment.center,
                  child: const Icon(Icons.person, size: 24, color: Color(0xFF7C5CFC)),
                );
              }
              return Image(
                image: CachedNetworkImageProvider(
                  url,
                  cacheManager: AppCacheManager.instance, // ★ 启用全局缓存
                ),
                width: 44, height: 44, fit: BoxFit.cover,
                gaplessPlayback: true, // ★★★ 新增这一行 ★★★
                frameBuilder: (_, child, __, ___) => child, // ★ 秒出无闪烁
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    width: 44, height: 44,
                    color: const Color(0xFFF0ECFF),
                    alignment: Alignment.center,
                    child: const Icon(Icons.person, size: 24, color: Color(0xFF7C5CFC)),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  width: 44, height: 44,
                  color: const Color(0xFFF0ECFF),
                  alignment: Alignment.center,
                  child: const Icon(Icons.person, size: 24, color: Color(0xFF7C5CFC)),
                ),
              );
            }

  Widget _avatarBox(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: _buildAvatar(url),
    );
  }

  Future<void> _saveImage(BuildContext context, String url) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('保存图片'),
          content: const Text('是否保存该图片到相册？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
          ],
        ),
      );
      if (confirmed != true) return;

      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        await Gal.putImageBytes(res.bodyBytes);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已保存到相册'), duration: Duration(seconds: 2)),
          );
        }
      }
    } catch (_) {}
  }

  // ===== 普通文字/图片气泡 =====
  Widget _buildNormalBubble(BuildContext context, bool isSelf) {
    final avatar = isSelf ? myAvatar : (msg.avatarUrl.isNotEmpty ? msg.avatarUrl : friendAvatar);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isSelf) _avatarBox(avatar),
          if (!isSelf) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (msg.nickname.isNotEmpty && !isSelf)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(msg.nickname, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                  ),
                _bubbleContent(context, isSelf),
              ],
            ),
          ),
          if (isSelf) const SizedBox(width: 8),
          if (isSelf) _avatarBox(avatar),
        ],
      ),
    );
  }

  Widget _bubbleContent(BuildContext context, bool isSelf) {
    final bgColor = isSelf ? const Color(0xFF95EC69) : Colors.white;
    final textColor = isSelf ? Colors.black87 : Colors.black87;

    if (msg.type == 2) {
      return GestureDetector(
        onTap: () => onTapImage?.call(msg.content),
        onLongPress: () => _saveImage(context, msg.content),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image(
                        image: CachedNetworkImageProvider(
                          msg.content,
                          cacheManager: AppCacheManager.instance, // ★ 启用全局缓存
                        ),
                        width: 180,
                        fit: BoxFit.cover,
                        frameBuilder: (_, child, __, ___) => child, // ★ 秒出无闪烁
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            width: 180, height: 120,
                            color: const Color(0xFFEEEEEE),
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFCCCCCC)),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          width: 180, height: 120,
                          color: const Color(0xFFEEEEEE),
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image, color: Color(0xFFCCCCCC)),
                        ),
                      ),
                    ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SelectableText(
        msg.content,
        style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
      ),
    );
  }

  // ===== 普通转账卡片 =====
  Widget _buildTransferCard(BuildContext context, bool isSelf) {
    final isSender = msg.uid == myUid;
    final avatar = isSender ? myAvatar : msg.avatarUrl;
    final moneyText = msg.money.abs().toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisAlignment: isSender ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isSender) _avatarBox(avatar.isEmpty ? friendAvatar : avatar),
          if (!isSender) const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onTap: () => onTapTransfer?.call(msg),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 220, minWidth: 160),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF8C00), Color(0xFFE94848)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(msg.status, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('￥$moneyText', style: const TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('简信转账', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
          if (isSender) const SizedBox(width: 8),
          if (isSender) _avatarBox(avatar.isEmpty ? myAvatar : avatar),
        ],
      ),
    );
  }

  // ===== 充值/提现卡片（统一处理） =====
  Widget _buildApplyCard(BuildContext context, bool isSelf, {required bool isRecharge}) {
    // 判断"我"是否发送者：msg.uid 或 playerUid 等于 myUid 都算
    final isSender = msg.uid == myUid || msg.playerUid == myUid;
    // 财务视角：不是发送者，且卡片待处理 → 可点击
    final clickable = msg.applyStatus == 0 && !isSender;

    // 根据 applyStatus 决定颜色
    List<Color> gradientColors;
    String titleText;
    String bodyText;
    String noteText;

    final playerNick = msg.playerNickname.isEmpty ? '玩家' : msg.playerNickname;
    final amtStr = msg.amount.toStringAsFixed(0);
    final rn = msg.roomnums;

    if (msg.applyStatus == 0) {
      // 待处理：橙红
      gradientColors = const [Color(0xFFFFB347), Color(0xFFFF8C00)];
      titleText = isRecharge ? '充值申请' : '提现申请';
      bodyText = '$playerNick 申请${isRecharge ? "充值" : "提现"} $amtStr 元（房间 $rn）';
      noteText = isSender ? '等待财务确认' : (clickable ? '点击处理' : '');
    } else if (msg.applyStatus == 1) {
      // 已完成：蓝色
      gradientColors = const [Color(0xFF3B82F6), Color(0xFF1D4ED8)];
      titleText = isRecharge ? '充值已完成' : '提现已完成';
      bodyText = '$playerNick ${isRecharge ? "充值" : "提现"} $amtStr 元已完成（房间 $rn）';
      noteText = '已完成';
    } else {
      // 已拒绝：红色
      gradientColors = const [Color(0xFFEF4444), Color(0xFFB91C1C)];
      titleText = isRecharge ? '充值已拒绝' : '提现已拒绝';
      bodyText = '$playerNick 申请${isRecharge ? "充值" : "提现"} $amtStr 元被拒绝（房间 $rn）';
      noteText = '已拒绝';
    }

    // 头像：自己发的显示自己，对方发的显示对方
    final avatar = isSender ? myAvatar : (msg.avatarUrl.isEmpty ? friendAvatar : msg.avatarUrl);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisAlignment: isSender ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isSender) _avatarBox(avatar),
          if (!isSender) const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onTap: clickable
                  ? () => isRecharge
                      ? onTapRecharge?.call(msg)
                      : onTapWithdraw?.call(msg)
                  : null,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 260, minWidth: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.last.withOpacity(0.25),
                      blurRadius: 8, offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titleText,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold,
                        )),
                    const SizedBox(height: 6),
                    Text(bodyText,
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
                    if (noteText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(noteText,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9), fontSize: 11,
                          )),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (isSender) const SizedBox(width: 8),
          if (isSender) _avatarBox(avatar),
        ],
      ),
    );
  }

  // ===== 六合彩转账卡片 =====
  Widget _buildLhcTransferCard(BuildContext context, bool isSelf) {
    final isSender = msg.uid == myUid;
    final avatar = isSender ? myAvatar : (msg.avatarUrl.isEmpty ? friendAvatar : msg.avatarUrl);
    final amountText = '￥${msg.amount.toStringAsFixed(2)}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisAlignment: isSender ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isSender) _avatarBox(avatar),
          if (!isSender) const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 240, minWidth: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF8C00), Color(0xFFE94848)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSender ? '转给 ${msg.toNickname}' : '来自 ${msg.nickname} 的转账',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(amountText,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    isSender ? '转账成功，已到账' : '已到账，可在账单查看',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.25))),
                    ),
                    child: Text('六合彩房间：${msg.roomnums}',
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
          if (isSelf) const SizedBox(width: 8),
          if (isSelf) _avatarBox(myAvatar),
        ],
      ),
    );
  }
}