import 'package:flutter/material.dart';
import 'package:senzu_player/senzu_player.dart';

class FeatureDataPolicyPage extends StatelessWidget {
  const FeatureDataPolicyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('12. Data Policy'), backgroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoBox(
              'When on cellular:\n'
              '• warnOnCellular=true → shows warning dialog\n'
              '• dataSaverOnCellular=true → auto-switches to low quality\n'
              '• dataSaverQualityKey → target quality key (e.g. "480p")',
            ),
            const SizedBox(height: 16),

            _label('Warn on cellular + data saver'),
            SenzuPlayer(
              source: {
                '1080p': VideoSource.fromUrl(
                  'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
                ),
                '720p': VideoSource.fromUrl(
                  'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
                ),
                '480p': VideoSource.fromUrl(
                  'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
                ),
              },
              dataPolicy: const SenzuDataPolicy(
                warnOnCellular: true,
                dataSaverOnCellular: true,
                dataSaverQualityKey: '480p',
              ),
              defaultAspectRatio: 16 / 9,
              meta: const SenzuMetaData(title: 'Data Policy Demo'),
              style: SenzuPlayerStyle(
                senzuLanguage: const SenzuLanguage(
                  cellularWarningTitle: 'Using Mobile Data',
                  cellularWarningBody: 'Streaming will consume your mobile data allowance.',
                  dataSaver: 'Data Saver',
                  cellularContinue: 'Continue',
                ),
              ),
            ),
            const SizedBox(height: 24),

            _label('No warning (SenzuDataPolicy.none)'),
            SenzuPlayer(
              source: {
                'Auto': VideoSource.fromUrl(
                  'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
                ),
              },
              dataPolicy: SenzuDataPolicy.none,
              defaultAspectRatio: 16 / 9,
              meta: const SenzuMetaData(title: 'No Data Warning'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(
                color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
      );

  Widget _infoBox(String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.7)),
      );
}
