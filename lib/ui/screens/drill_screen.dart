import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/liquid_theme.dart';
import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';
import '../../providers/srs_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/path_provider.dart';

class DrillScreen extends ConsumerStatefulWidget {
  final String moduleId;
  const DrillScreen({super.key, required this.moduleId});

  @override
  ConsumerState<DrillScreen> createState() => _DrillScreenState();
}

class _DrillScreenState extends ConsumerState<DrillScreen> {
  int currentIndex = 0;
  bool isFlipped = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lang = ref.read(activeLanguageProvider);
      ref.read(srsProvider.notifier).loadDrill(lang);
    });
  }

  @override
  Widget build(BuildContext context) {
    final srsState = ref.watch(srsProvider);
    final items = srsState.deck;

    if (srsState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (items.isEmpty) {
       return GlassScaffold(
         title: 'Drill', 
         subtitle: 'Practice',
         body: SliverFillRemaining(
           child: Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 const Text("No drill items available right now.", style: TextStyle(color: Colors.white)),
                 const SizedBox(height: 20),
                 LiquidButton(text: "Go Back", onTap: () => context.pop())
               ],
             ),
           ),
         ),
       );
    }

    if (currentIndex >= items.length) {
       // Completed
       return GlassScaffold(
         title: 'Complete!', 
         subtitle: 'Great job',
         body: SliverFillRemaining(
           child: Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 const Icon(Icons.check_circle, size: 80, color: Colors.greenAccent),
                 const SizedBox(height: 20),
                 const Text("Drill Completed", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 40),
                 LiquidButton(text: "Finish", onTap: () {
                   // Mark activity as done
                   ref.read(pathNotifierProvider.notifier).updateActivity(
                     widget.moduleId, 
                     'drill', 
                     true,
                     {'completedAt': DateTime.now().toIso8601String()}
                   );
                   context.pop();
                 })
               ],
             ),
           ),
         ),
       );
    }

    final currentItem = items[currentIndex];

    return GlassScaffold(
      title: 'Drill',
      subtitle: '${currentIndex + 1} / ${items.length}',
      body: SliverFillRemaining(
        hasScrollBody: false,
        child: Column(
          children: [
            const SizedBox(height: 40),
            GestureDetector(
              onTap: () => setState(() => isFlipped = !isFlipped),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, anim) {
                   final rotate = Tween(begin: 3.14, end: 0.0).animate(anim);
                   return AnimatedBuilder(
                     animation: rotate,
                     child: child,
                     builder: (context, child) {
                       return Transform(
                         transform: Matrix4.rotationY(rotate.value),
                         alignment: Alignment.center,
                         child: child,
                       );
                     },
                   );
                },
                child: isFlipped 
                  ? _CardFace(key: const ValueKey(true), text: currentItem.back, label: "ANSWER", color: Colors.greenAccent)
                  : _CardFace(key: const ValueKey(false), text: currentItem.front, label: "QUESTION", color: LiquidTheme.primaryAccent),
              ),
            ),
            const Spacer(),
            if (isFlipped)
               Padding(
                 padding: const EdgeInsets.only(bottom: 40),
                 child: Row(
                   children: [
                     Expanded(child: LiquidButton(text: "Next", onTap: () {
                        setState(() {
                          currentIndex++;
                          isFlipped = false;
                        });
                     })),
                   ],
                 ),
               )
            else
               const Padding(
                 padding: EdgeInsets.only(bottom: 40),
                 child: Text("Tap card to reveal answer", style: TextStyle(color: Colors.white54)),
               )
          ],
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  final String text;
  final String label;
  final Color color;

  const _CardFace({super.key, required this.text, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Container(
        height: 300,
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 24),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
