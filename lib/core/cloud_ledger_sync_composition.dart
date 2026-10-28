import 'package:stellar_pos/core/cloud_ledger_remote_applier.dart';
import 'package:stellar_pos/core/cloud_ledger_repository_handlers.dart';
import 'package:stellar_pos/core/cloud_ledger_sync.dart';
import 'package:stellar_pos/core/hive_cloud_ledger_apply_receipt_store.dart';

/// Creates the durable ledger applier with the Hive receipt store and the
/// repository handlers used by the current local data layer. Call explicitly;
/// this factory does not start pulls or enable background synchronization.
Future<CloudLedgerRemoteApplier> createHiveCloudLedgerRemoteApplier({
  String receiptBoxName = 'cloud_ledger_apply_receipts',
  CloudLedgerRepositoryHandlers? repositoryHandlers,
}) async {
  final receipts = await HiveCloudLedgerApplyReceiptStore.open(
    boxName: receiptBoxName,
  );
  final handlers = repositoryHandlers ?? CloudLedgerRepositoryHandlers();
  return DurableCloudLedgerRemoteApplier(
    receipts: receipts,
    handlers: handlers.handlers,
  );
}
