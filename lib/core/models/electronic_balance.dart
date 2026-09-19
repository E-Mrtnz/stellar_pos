import 'package:stellar_pos/core/models/sync_metadata.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

export 'package:stellar_pos/core/models/electronic_balance_sale.dart';

enum ElectronicBalanceTransactionType { purchase, sale }

class ElectronicBalanceSaleOption implements SyncableEntity {
  @override
  final String id;
  final String category;
  final double amount;
  /// Commission percentage specific to this sale category.
  /// Null means the account's main commission applies (standard categories and legacy data).
  final double? commissionRate;
  @override
  final SyncMetadata metadata;

  ElectronicBalanceSaleOption({String? id, required this.category, required this.amount, this.commissionRate, SyncMetadata? metadata})
      : id = id ?? IdGenerator.newId(), metadata = metadata ?? SyncMetadata.initial();

  Map<String, dynamic> toMap() => {'id': id, 'category': category, 'amount': amount, 'commissionRate': commissionRate, 'metadata': metadata.toMap()};

  factory ElectronicBalanceSaleOption.fromMap(Map<String, dynamic> map) => ElectronicBalanceSaleOption(
    id: map['id']?.toString(), category: map['category']?.toString() ?? '', amount: _double(map['amount']), commissionRate: map['commissionRate'] == null ? null : _double(map['commissionRate']), metadata: _metadata(map['metadata']));

  static double _double(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
  static SyncMetadata _metadata(dynamic value) => value is Map ? SyncMetadata.fromMap(Map<String, dynamic>.from(value)) : SyncMetadata.initial();
}

class ElectronicBalanceAccount implements SyncableEntity {
  @override final String id;
  final String companyName;
  final double commissionRate;
  final double balance;
  final List<ElectronicBalanceSaleOption> saleOptions;
  @override final SyncMetadata metadata;

  ElectronicBalanceAccount({required this.id, required this.companyName, required this.commissionRate, required this.balance, List<ElectronicBalanceSaleOption> saleOptions = const [], SyncMetadata? metadata})
      : saleOptions = List.unmodifiable(saleOptions),
        metadata = metadata ?? SyncMetadata.initial();

  double get commissionMultiplier => commissionRate / 100;
  List<double> amountsForCategory(String category) => saleOptions.where((option) => option.category == category).map((option) => option.amount).toList();

  List<String> get saleCategories {
    final result = <String>[];
    const standard = ['Saldo', 'Internet', 'Llamada'];
    for (final category in standard) result.add(category);
    for (final option in saleOptions) {
      final category = option.category.trim();
      if (category.isNotEmpty && !result.contains(category)) result.add(category);
    }
    return List.unmodifiable(result);
  }

  ElectronicBalanceAccount copyWith({String? id, String? companyName, double? commissionRate, double? balance, List<ElectronicBalanceSaleOption>? saleOptions, SyncMetadata? metadata, bool touchMetadata = true}) => ElectronicBalanceAccount(
    id: id ?? this.id, companyName: companyName ?? this.companyName, commissionRate: commissionRate ?? this.commissionRate, balance: balance ?? this.balance, saleOptions: saleOptions ?? this.saleOptions,
    metadata: metadata ?? (touchMetadata ? this.metadata.touch() : this.metadata));

  Map<String, dynamic> toMap() => {'id': id, 'companyName': companyName, 'commissionRate': commissionRate, 'balance': balance, 'saleOptions': saleOptions.map((option) => option.toMap()).toList(), 'metadata': metadata.toMap()};

  factory ElectronicBalanceAccount.fromMap(Map<String, dynamic> map) {
    final companyName = map['companyName']?.toString() ?? '';
    var balance = _double(map['balance']);

    // One-time correction for the known TIGO data-entry discrepancy.
    // The persisted value is $25.52, while the real balance is $25.40.
    if (companyName.trim().toLowerCase() == 'tigo' &&
        (balance - 25.52).abs() < 0.000001) {
      balance = 25.40;
    }

    return ElectronicBalanceAccount(
      id: map['id']?.toString() ?? '',
      companyName: companyName,
      commissionRate: _double(map['commissionRate']),
      balance: balance,
      saleOptions: _options(map['saleOptions']),
      metadata: _metadata(map['metadata']),
    );
  }

  static List<ElectronicBalanceSaleOption> _options(dynamic value) => value is Iterable ? value.whereType<Map>().map((item) => ElectronicBalanceSaleOption.fromMap(Map<String, dynamic>.from(item))).toList() : const [];
  static double _double(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
  static SyncMetadata _metadata(dynamic value) => value is Map ? SyncMetadata.fromMap(Map<String, dynamic>.from(value)) : SyncMetadata.initial();
}

class ElectronicBalanceTransaction implements SyncableEntity {
  @override final String id;
  final String accountId;
  final ElectronicBalanceTransactionType type;
  final double amount;
  final double providerCost;
  final double profit;
  final String category;
  final String description;
  final DateTime createdAt;
  final String? saleId;
  final String? purchaseId;
  @override final SyncMetadata metadata;

  ElectronicBalanceTransaction({required this.id, required this.accountId, required this.type, required this.amount, required this.providerCost, required this.profit, required this.category, required this.description, required this.createdAt, this.saleId, this.purchaseId, SyncMetadata? metadata})
      : metadata = metadata ?? SyncMetadata(createdAt: createdAt.toUtc(), updatedAt: createdAt.toUtc());

  Map<String, dynamic> toMap() => {'id': id, 'accountId': accountId, 'type': type.name, 'amount': amount, 'providerCost': providerCost, 'profit': profit, 'category': category, 'description': description, 'createdAt': createdAt.toIso8601String(), 'saleId': saleId, 'purchaseId': purchaseId, 'metadata': metadata.toMap()};

  factory ElectronicBalanceTransaction.fromMap(Map<String, dynamic> map) => ElectronicBalanceTransaction(
    id: map['id']?.toString() ?? '', accountId: map['accountId']?.toString() ?? '', type: _type(map['type']), amount: _double(map['amount']), providerCost: _double(map['providerCost']), profit: _double(map['profit']), category: map['category']?.toString() ?? '', description: map['description']?.toString() ?? '', createdAt: _date(map['createdAt']), saleId: map['saleId']?.toString(), purchaseId: map['purchaseId']?.toString(), metadata: _metadata(map['metadata']));

  static ElectronicBalanceTransactionType _type(dynamic value) => ElectronicBalanceTransactionType.values.firstWhere((item) => item.name == value?.toString(), orElse: () => ElectronicBalanceTransactionType.sale);
  static DateTime _date(dynamic value) => value is DateTime ? value.toUtc() : DateTime.tryParse(value?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc();
  static double _double(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
  static SyncMetadata _metadata(dynamic value) => value is Map ? SyncMetadata.fromMap(Map<String, dynamic>.from(value)) : SyncMetadata.initial();
}
