class ImMessage {
  const ImMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    required this.isSelf,
    this.receiverId,
    this.isSystem = false,
  });

  final String id;
  final String text;
  final String senderId;
  final String? receiverId;
  final DateTime timestamp;
  final bool isSelf;
  final bool isSystem;

  factory ImMessage.fromJson(
    Map<String, dynamic> json, {
    required String? selfId,
    bool forceSelf = false,
  }) {
    final senderId = json['from'] as String? ?? json['senderId'] as String? ?? '';
    final timestampMs = json['timestamp'] as int?;

    return ImMessage(
      id: json['id'] as String? ?? '${timestampMs ?? DateTime.now().millisecondsSinceEpoch}',
      text: json['text'] as String? ?? json['content'] as String? ?? '',
      senderId: senderId,
      receiverId: json['to'] as String? ?? json['receiverId'] as String?,
      timestamp: timestampMs != null
          ? DateTime.fromMillisecondsSinceEpoch(timestampMs)
          : DateTime.now(),
      isSelf: forceSelf || (selfId != null && senderId == selfId),
      isSystem: json['type'] == 'system',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': isSystem ? 'system' : 'message',
      'id': id,
      'text': text,
      'from': senderId,
      if (receiverId != null) 'to': receiverId,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}
