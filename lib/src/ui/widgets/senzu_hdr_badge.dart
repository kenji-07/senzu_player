import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';

class SenzuHdrBadge extends StatelessWidget {
  const SenzuHdrBadge({super.key, required this.bundle});
  final SenzuPlayerBundle bundle;

  @override
  Widget build(BuildContext context) => Obx(() {
        if (!bundle.core.isHdrEnabled.value) return const SizedBox.shrink();
        return Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('HDR',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                )),
          ),
        );
      });
}
