import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_screen_header.dart';
import '../../../../shared/widgets/nebula_segmented_control.dart';

/// Admin search hub: teachers (with drill to their students) and a studio-wide
/// student search, behind a segmented control.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  int _segment = 0; // 0 = Педагоги, 1 = Ученики

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: AppScreenHeader(
                title: 'Поиск',
                subtitle: 'Педагоги и ученики студии',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: NebulaSegmentedControl(
                segments: const ['Педагоги', 'Ученики'],
                selectedIndex: _segment,
                onChanged: (i) => setState(() => _segment = i),
              ),
            ),
            Expanded(
              child: _segment == 0
                  ? const _TeachersSearchTab()
                  : const _StudentsSearchTab(),
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder tabs — filled in by Tasks 2 and 3.
class _TeachersSearchTab extends StatelessWidget {
  const _TeachersSearchTab();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Педагоги'));
}

class _StudentsSearchTab extends StatelessWidget {
  const _StudentsSearchTab();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Ученики'));
}
