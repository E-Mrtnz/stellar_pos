import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/provider_person.dart';
import 'package:stellar_pos/core/providers/providers_provider.dart';
import 'package:stellar_pos/presentation/providers/widgets/create_provider_dialog.dart';
import 'package:stellar_pos/presentation/providers/widgets/manage_distributors_dialog.dart';

class ProvidersLayout extends StatefulWidget {
  const ProvidersLayout({super.key});

  @override
  State<ProvidersLayout> createState() => _ProvidersLayoutState();
}

class _ProvidersLayoutState extends State<ProvidersLayout> {
  static const List<String> _weekdays = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  String _selectedType = 'Repartidor';

  bool get _showDeliveryPeople => _selectedType == 'Repartidor';

  Future<void> _createRoute() async {
    await CreateProviderDialog.show(context);
  }

  Future<void> _editRoute(ProviderRoute route) async {
    await CreateProviderDialog.show(context, route: route);
  }

  Future<void> _manageDistributors() async {
    await ManageDistributorsDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final routes = context.watch<ProvidersProvider>().byType(_selectedType);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            child: Row(
              children: [
                Expanded(flex: 3, child: _buildCalendarCard(routes)),
                const SizedBox(width: AppDimensions.productGridSpacing),
                Expanded(flex: 1, child: _buildPeopleCard(routes)),
              ],
            ),
          ),
          _buildFloatingActions(),
        ],
      ),
    );
  }

  Widget _buildCalendarCard(List<ProviderRoute> routes) {
    final byDay = List<List<ProviderRoute>>.generate(
      7,
      (day) => routes.where((route) => route.hasWeekday(day)).toList(),
    );
    final rowCount = byDay.fold<int>(
      0,
      (max, dayRoutes) => dayRoutes.length > max ? dayRoutes.length : max,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.largeCardRadius),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildCalendarHeader(),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: rowCount == 0
                ? _buildEmptyCalendar()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: rowCount,
                    itemBuilder: (context, rowIndex) =>
                        _buildCalendarRow(rowIndex + 1, byDay),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      child: Row(
        children: [
          const SizedBox(width: 34),
          ..._weekdays.map(
            (day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarRow(int rowNumber, List<List<ProviderRoute>> byDay) {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Center(
              child: Text(
                '$rowNumber',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          ...List<Widget>.generate(7, (dayIndex) {
            final dayRoutes = byDay[dayIndex];
            final route = rowNumber <= dayRoutes.length
                ? dayRoutes[rowNumber - 1]
                : null;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                child: route == null
                    ? const SizedBox.expand()
                    : _buildEventCard(route),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEventCard(ProviderRoute route) {
    final color = Color(route.colorValue);
    final icon = route.isDeliveryPerson
        ? Icons.local_shipping_outlined
        : Icons.storefront_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withOpacity(0.65)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              route.distributorName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleCard(List<ProviderRoute> routes) {
    final title = _showDeliveryPeople ? 'Repartidores' : 'Vendedores';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.largeCardRadius),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Distribuidora',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Asignar ruta de Proveedor',
                onPressed: _createRoute,
                icon: const Icon(Icons.route_outlined),
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),
          Expanded(
            child: routes.isEmpty
                ? Center(
                    child: Text(
                      'No hay ${title.toLowerCase()} registrados.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: routes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _buildRouteListItem(routes[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteListItem(ProviderRoute route) {
    final color = Color(route.colorValue);
    final icon = route.isDeliveryPerson
        ? Icons.local_shipping_outlined
        : Icons.storefront_outlined;
    final days = route.weekdays.map((day) => _weekdays[day]).join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route.distributorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  days,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar ruta',
            onPressed: () => _editRoute(route),
            icon: const Icon(Icons.edit_outlined, size: 17),
            color: AppColors.primary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActions() {
    return Positioned(
      right: 20,
      bottom: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'fab_provider_switch',
            tooltip: 'Alternar repartidores y vendedores',
            onPressed: () {
              setState(() {
                _selectedType = _showDeliveryPeople
                    ? 'Vendedor'
                    : 'Repartidor';
              });
            },
            elevation: AppDimensions.inventoryFabElevation,
            shape: const CircleBorder(),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'fab_manage_distributors',
            tooltip: 'Administrar distribuidoras',
            onPressed: _manageDistributors,
            elevation: AppDimensions.inventoryFabElevation,
            shape: const CircleBorder(),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.business_outlined, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCalendar() {
    return const Center(
      child: Text(
        'No hay eventos programados.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
    );
  }
}
