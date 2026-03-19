import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../providers/connectivity_provider.dart';
import '../../../../services/sync_service.dart';
import '../../../widgets/liquid_components.dart';

class ProfileSyncStatusSection extends ConsumerWidget {
  const ProfileSyncStatusSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);
    final syncQueueCount = ref.watch(syncQueueCountProvider);
    final lastSyncTime = ref.watch(lastSyncTimeProvider);
    final isSyncing = ref.watch(isSyncingProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: isOnline ? Colors.greenAccent : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                isOnline ? "Online" : "Offline",
                style: TextStyle(
                  color: isOnline ? Colors.greenAccent : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          syncQueueCount.when(
            data: (count) => Row(
              children: [
                const Icon(Icons.sync, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                Text(
                  isSyncing
                      ? "Syncing $count changes..."
                      : "Pending changes: $count",
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            loading: () => const Text(
              "Checking sync queue...",
              style: TextStyle(color: Colors.white38),
            ),
            error: (_, _) => const Text(
              "Unable to check sync status",
              style: TextStyle(color: Colors.white38),
            ),
          ),
          const SizedBox(height: 8),
          lastSyncTime != null
              ? Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: Colors.white38,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Last synced: ${DateFormat.yMd().add_jm().format(lastSyncTime)}",
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              : const Text(
                  "Never synced",
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
          if (isOnline)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: LiquidButton(
                text: isSyncing ? "Syncing..." : "Sync Now",
                isLoading: isSyncing,
                onTap: () => isSyncing
                    ? null
                    : ref
                          .read(syncServiceProvider)
                          .syncPendingMutations(force: true),
              ),
            ),
        ],
      ),
    );
  }
}
