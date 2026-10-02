
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/debt_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/core/providers/purchases_provider.dart';
import 'package:stellar_pos/core/providers/sales_provider.dart';

enum _StatsPeriod { day, week, month, year, custom }

class _StatsRange {
  final DateTime start, end;
  const _StatsRange(this.start, this.end);
  Duration get duration => end.difference(start);
  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);
}

class StatisticsLayout extends StatefulWidget {
  const StatisticsLayout({super.key});
  @override State<StatisticsLayout> createState() => _StatisticsLayoutState();
}

class _StatisticsLayoutState extends State<StatisticsLayout> {
  _StatsPeriod _period = _StatsPeriod.month;
  DateTime _anchor = DateTime.now();
  DateTime? _customStart, _customEnd;

  _StatsRange get _range {
    final d = DateTime(_anchor.year, _anchor.month, _anchor.day);
    switch (_period) {
      case _StatsPeriod.day: return _StatsRange(d, d.add(const Duration(days: 1)));
      case _StatsPeriod.week:
        final s = d.subtract(Duration(days: d.weekday - 1));
        return _StatsRange(s, s.add(const Duration(days: 7)));
      case _StatsPeriod.month: return _StatsRange(DateTime(d.year, d.month), DateTime(d.year, d.month + 1));
      case _StatsPeriod.year: return _StatsRange(DateTime(d.year), DateTime(d.year + 1));
      case _StatsPeriod.custom:
        final s = _customStart ?? d, e = _customEnd ?? d;
        return _StatsRange(DateTime(s.year, s.month, s.day), DateTime(e.year, e.month, e.day + 1));
    }
  }

  _StatsRange get _previous {
    final r = _range;
    switch (_period) {
      case _StatsPeriod.day: return _StatsRange(r.start.subtract(const Duration(days: 1)), r.start);
      case _StatsPeriod.week: return _StatsRange(r.start.subtract(const Duration(days: 7)), r.start);
      case _StatsPeriod.month:
        final s = DateTime(r.start.year, r.start.month - 1); return _StatsRange(s, r.start);
      case _StatsPeriod.year:
        final s = DateTime(r.start.year - 1); return _StatsRange(s, r.start);
      case _StatsPeriod.custom: return _StatsRange(r.start.subtract(r.duration), r.start);
    }
  }

  Future<void> _pickDate() async {
    if (_period == _StatsPeriod.custom) {
      final s = await showDatePicker(context: context, initialDate: _customStart ?? _anchor, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
      if (s == null || !mounted) {
        return;
      }
      final e = await showDatePicker(context: context, initialDate: _customEnd ?? s, firstDate: s, lastDate: DateTime.now().add(const Duration(days: 365)));
      if (e == null) {
        return;
      }
      setState(() { _customStart = s; _customEnd = e; });
    } else {
      final d = await showDatePicker(context: context, initialDate: _anchor, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
      if (d != null) {
        setState(() => _anchor = d);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sales = context.watch<SalesProvider>().sales;
    final products = context.watch<ProductProvider>().products;
    final purchases = context.watch<PurchasesProvider>().purchases;
    final debts = context.watch<DebtProvider>();
    final r = _range, p = _previous;
    final cs = sales.where((x) => r.contains(x.createdAt)).toList(growable: false);
    final ps = sales.where((x) => p.contains(x.createdAt)).toList(growable: false);
    final cp = purchases.where((x) => r.contains(x.arrivalAt)).toList(growable: false);
    final pp = purchases.where((x) => p.contains(x.arrivalAt)).toList(growable: false);
    final a = _Snapshot.from(cs, cp), b = _Snapshot.from(ps, pp);
    final compact = MediaQuery.sizeOf(context).width < 900;

    final content = <Widget>[
      _header(),
      const SizedBox(height: 12),
      _Kpis([
        _Kpi('Ventas', _money(a.sales), Icons.point_of_sale_outlined, AppColors.primary, _change(a.sales, b.sales), a.count.toString() + ' ventas'),
        _Kpi('Ganancia', _money(a.profit), Icons.trending_up_rounded, AppColors.successGreen, _change(a.profit, b.profit), 'Margen ${_pct}'(a.margin)),
        _Kpi('Costo de ventas', _money(a.cost), Icons.inventory_2_outlined, AppColors.warningOrange, _change(a.cost, b.cost), a.sales == 0 ? 'Sin ventas' : _pct(a.costRatio) + ' de ventas'),
        _Kpi('Por cobrar', _money(debts.totalRemaining), Icons.account_balance_wallet_outlined, AppColors.dangerRed, null, 'Saldo actual · ${debts.clientsWithDebt.toString}'() + ' clientes'),
      ], compact),
      const SizedBox(height: 12),
      _Panel(title: 'Evolución de ventas', trailing: Text(_rangeLabel(r), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)), child: SizedBox(height: 235, child: _Trend(_trend(sales, r)))),
      const SizedBox(height: 12),
    ];

    if (compact) {
      content.addAll([
        _Products(_topProducts(cs)), const SizedBox(height: 12),
        _Clients(_topClients(cs)), const SizedBox(height: 12),
        _Distribution('Métodos de pago', _paymentMix(cs)), const SizedBox(height: 12),
        _Distribution('Horario de ventas', _hourMix(cs)),
      ]);
    } else {
      content.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _Products(_topProducts(cs))), const SizedBox(width: 12),
        Expanded(child: _Clients(_topClients(cs))),
      ]));
      content.addAll([
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _Distribution('Métodos de pago', _paymentMix(cs))), const SizedBox(width: 12),
          Expanded(child: _Distribution('Horario de ventas', _hourMix(cs))),
        ]),
      ]);
    }

    content.addAll([
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _Mini('Compras', Icons.shopping_cart_outlined, [
          ['Total', _money(a.purchases)],
          ['Operaciones', cp.length.toString()],
          ['Proveedores', cp.map((x) => x.distributorName.trim()).where((x) => x.isNotEmpty).toSet().length.toString()],
        ], _change(a.purchases, b.purchases))),
        const SizedBox(width: 12),
        Expanded(child: _Mini('Inventario', Icons.inventory_2_outlined, [
          ['Productos', products.length.toString()],
          ['Bajo stock', products.where((x) => x.stock > 0 && x.stock <= x.minStock).length.toString()],
          ['Agotados', products.where((x) => x.stock <= 0).length.toString()],
          ['Valor', _money(products.fold<double>(0, (s, x) => s + x.cost * x.stock))],
        ], null)),
      ]),
    ]);

    return ColoredBox(
      color: AppColors.inputBackground,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content),
        )),
      ),
    );
  }

  Widget _header() => LayoutBuilder(builder: (context, constraints) {
    final compact = constraints.maxWidth < 650;
    final selector = DropdownButtonHideUnderline(
      child: DropdownButton<_StatsPeriod>(
        value: _period,
        items: const [
          DropdownMenuItem(value: _StatsPeriod.day, child: Text('Diario')),
          DropdownMenuItem(value: _StatsPeriod.week, child: Text('Semanal')),
          DropdownMenuItem(value: _StatsPeriod.month, child: Text('Mensual')),
          DropdownMenuItem(value: _StatsPeriod.year, child: Text('Anual')),
          DropdownMenuItem(value: _StatsPeriod.custom, child: Text('Personalizado')),
        ],
        onChanged: (v) {
          if (v != null) {
            setState(() {
              _period = v;
              if (v == _StatsPeriod.custom) {
                _customStart = _anchor;
                _customEnd = _anchor;
              }
            });
          }
        },
      ),
    );
    final dateButton = OutlinedButton.icon(
      onPressed: _pickDate,
      icon: const Icon(Icons.calendar_month_outlined, size: 16),
      label: Text(_period == _StatsPeriod.custom ? _rangeLabel(_range) : _anchorLabel()),
    );
    const title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Estadísticas', style: AppTextStyles.brandTitle),
        SizedBox(height: 3),
        Text('Resumen general del rendimiento de tu negocio', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
    return compact
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [title, const SizedBox(height: 8), Wrap(alignment: WrapAlignment.end, spacing: 8, children: [selector, dateButton])])
        : Row(children: [Expanded(child: title), selector, const SizedBox(width: 8), dateButton]);
  });
  String _anchorLabel() {
    switch (_period) {
      case _StatsPeriod.day: return _date(_anchor);
      case _StatsPeriod.week: return _shortDate(_range.start) + ' - ${_shortDate}'(_range.end.subtract(const Duration(days: 1)));
      case _StatsPeriod.month: return _month(_anchor.month) + ' ${_anchor.year.toString}'();
      case _StatsPeriod.year: return _anchor.year.toString();
      case _StatsPeriod.custom: return _rangeLabel(_range);
    }
  }
}

class _Snapshot {
  final double sales, profit, cost, purchases; final int count;
  const _Snapshot(this.sales, this.profit, this.cost, this.purchases, this.count);
  double get margin => sales <= 0 ? 0 : profit / sales;
  double get costRatio => sales <= 0 ? 0 : cost / sales;
  factory _Snapshot.from(List<SaleRecord> sales, List purchases) {
    var s = 0.0, p = 0.0, c = 0.0, n = 0;
    for (final x in sales) {
      if (x.isAnnulled) {
        continue;
      }
      n++; s += x.effectiveTotal; p += x.effectiveProfit; c += _saleCost(x);
    }
    return _Snapshot(s, p, c, purchases.fold<double>(0, (v, x) => v + x.total), n);
  }
}

class _Kpi { final String title, value, caption; final IconData icon; final Color color; final double? change; const _Kpi(this.title,this.value,this.icon,this.color,this.change,this.caption); }
class _Kpis extends StatelessWidget {
  final List<_Kpi> data; final bool compact;
  const _Kpis(this.data,this.compact);
  @override Widget build(BuildContext c) {
    final rows = compact ? <Widget>[
      Row(children: [Expanded(child:_KpiCard(data[0])),const SizedBox(width:10),Expanded(child:_KpiCard(data[1]))]),
      const SizedBox(height:10),
      Row(children: [Expanded(child:_KpiCard(data[2])),const SizedBox(width:10),Expanded(child:_KpiCard(data[3]))]),
    ] : <Widget>[Row(children:[for(var i=0;i<data.length;i++)...[if(i>0)const SizedBox(width:10),Expanded(child:_KpiCard(data[i]))]])];
    return Column(children: rows);
  }
}
class _KpiCard extends StatelessWidget {
  final _Kpi k;
  const _KpiCard(this.k);

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 126),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: k.color.withAlpha(32)),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(height: 5, color: k.color),
            ),
            Positioned(
              right: -18,
              bottom: -24,
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: k.color.withAlpha(12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: k.color.withAlpha(22),
                        ),
                        child: Icon(k.icon, color: k.color, size: 18),
                      ),
                      const Spacer(),
                      if (k.change != null) _Change(k.change!),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(k.title, style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  )),
                  const SizedBox(height: 2),
                  Text(k.value, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 21, height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: k.color,
                    )),
                  const SizedBox(height: 3),
                  Text(k.caption, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      );
}
class _Change extends StatelessWidget { final double value; const _Change(this.value); @override Widget build(BuildContext c){final pos=value>=0,color=pos?AppColors.successGreen:AppColors.dangerRed;return Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),decoration:BoxDecoration(color:color.withAlpha(20),borderRadius:BorderRadius.circular(20)),child:Text((pos?'↑ ':'↓ ')+_pct(value.abs()),style:TextStyle(color:color,fontSize:9,fontWeight:FontWeight.w800)));}}
class _Panel extends StatelessWidget {
  final String title; final Widget? trailing; final Widget child;
  const _Panel({required this.title,this.trailing,required this.child});
  @override Widget build(BuildContext c)=>Container(
    padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppColors.cardBackground,borderRadius:BorderRadius.circular(AppDimensions.cardRadius),border:Border.all(color:AppColors.border),boxShadow:const[BoxShadow(color:AppColors.shadowColor,blurRadius:10,offset:Offset(0,3))]),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Row(children:[Text(title,style:AppTextStyles.sectionTitle),const Spacer(),if(trailing!=null)trailing!]),const SizedBox(height:10),child]));
}
class _Trend extends StatelessWidget {
  final List<_Point> points;
  const _Trend(this.points);

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(
        child: Text(
          'No hay datos en este período.',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const left = 10.0;
        const right = 10.0;
        const bottom = 30.0;
        final chartWidth = constraints.maxWidth - left - right;
        final slotWidth = chartWidth / points.length;

        return Stack(
          children: [
            CustomPaint(
              painter: _BarTrendPainter(points),
              size: Size.infinite,
            ),
            for (var i = 0; i < points.length; i++)
              Positioned(
                left: left + i * slotWidth,
                top: 0,
                width: slotWidth,
                bottom: bottom,
                child: Tooltip(
                  preferBelow: false,
                  waitDuration: const Duration(milliseconds: 150),
                  showDuration: const Duration(seconds: 3),
                  message: '${points[i].label} - Ventas: ${_money(points[i].value)}',
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        );
      },
    );
  }
}
class _Point {
  final String label;
  final double value;
  const _Point(this.label, this.value);
}

class _BarTrendPainter extends CustomPainter {
  final List<_Point> points;
  _BarTrendPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 10.0, top = 12.0, bottom = 30.0, right = 10.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    final maxValue =
        points.fold<double>(0, (max, point) => math.max(max, point.value));

    if (maxValue <= 0) {
      return;
    }

    final gridPaint = Paint()..color = AppColors.border..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = top + chartHeight * i / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);
    }

    final visible = points.length;
    final gap = visible > 18 ? 4.0 : 8.0;
    final slotWidth = chartWidth / visible;
    final barWidth = math.max(5.0, math.min(28.0, slotWidth - gap));
    final labelStep = math.max(1, (visible / 8).ceil());

    for (var i = 0; i < visible; i++) {
      final point = points[i];
      final barHeight = (point.value / maxValue) * chartHeight;
      final x = left + i * slotWidth + (slotWidth - barWidth) / 2;
      final y = top + chartHeight - barHeight;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, math.max(barHeight, 2)),
        const Radius.circular(8),
      );

      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.primary, AppColors.primary.withAlpha(145)],
      );
      canvas.drawRRect(
        rect,
        Paint()..shader = gradient.createShader(
          Rect.fromLTWH(x, y, barWidth, math.max(barHeight, 2)),
        ),
      );

      if (i % labelStep == 0 || i == visible - 1) {
        final tp = TextPainter(
          text: TextSpan(
            text: point.label,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas,
          Offset(x + (barWidth - tp.width) / 2, size.height - 20));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarTrendPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _Products extends StatelessWidget {
  final List<_ProductStat> data; const _Products(this.data);
  @override Widget build(BuildContext c)=>_Panel(title:'Productos destacados',child:data.isEmpty?const _Empty('No hay ventas de productos en este período.'):Column(children:[for(var i=0;i<data.length;i++)...[if(i>0)const Divider(height:14),Row(children:[Container(width:28,height:28,decoration:BoxDecoration(color:AppColors.primaryLight,borderRadius:BorderRadius.circular(8)),child:Center(child:Text((i+1).toString(),style:const TextStyle(color:AppColors.primary,fontSize:10,fontWeight:FontWeight.w800)))),const SizedBox(width:8),Expanded(child:Text(data[i].name,overflow:TextOverflow.ellipsis,style:AppTextStyles.productName)),Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(data[i].quantity.toString()+' und.',style:const TextStyle(fontSize:9,color:AppColors.textSecondary)),Text(_money(data[i].sales),style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700))])])]]));
}
class _Clients extends StatelessWidget {
  final List<_ClientStat> data; const _Clients(this.data);
  @override Widget build(BuildContext c)=>_Panel(title:'Clientes con mayor volumen',child:data.isEmpty?const _Empty('No hay ventas con clientes registrados.'):Column(children:[for(var i=0;i<data.length;i++)...[if(i>0)const Divider(height:14),Row(children:[Expanded(child:Text(data[i].name,overflow:TextOverflow.ellipsis,style:AppTextStyles.productName)),Text(data[i].count.toString()+' ventas',style:const TextStyle(fontSize:9,color:AppColors.textSecondary)),const SizedBox(width:10),Text(_money(data[i].amount),style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700))])]]));
}
class _Distribution extends StatelessWidget {
  final String title; final List<_Dist> data; const _Distribution(this.title,this.data);
  @override Widget build(BuildContext c){final total=data.fold<double>(0,(s,x)=>s+x.value);return _Panel(title:title,child:data.isEmpty?const _Empty('No hay datos en este período.'):Column(children:[for(var i=0;i<data.length;i++)...[if(i>0)const SizedBox(height:10),Row(children:[Expanded(child:Text(data[i].label,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w600))),Text(_pct(total==0?0:data[i].value/total),style:const TextStyle(fontSize:9,fontWeight:FontWeight.w700,color:AppColors.textSecondary))]),const SizedBox(height:5),ClipRRect(borderRadius:BorderRadius.circular(20),child:LinearProgressIndicator(value:total==0?0:data[i].value/total,minHeight:7,backgroundColor:AppColors.chipBackground,valueColor:AlwaysStoppedAnimation<Color>(i==0?AppColors.primary:i==1?AppColors.successGreen:i==2?AppColors.warningOrange:AppColors.textMuted)))]]));}
}
class _Mini extends StatelessWidget {
  final String title; final IconData icon; final List<List<String>> values; final double? change; const _Mini(this.title,this.icon,this.values,this.change);
  @override Widget build(BuildContext c)=>_Panel(title:title,trailing:change==null?null:_Change(change!),child:Wrap(spacing:24,runSpacing:12,children:values.map((v)=>Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:13,color:AppColors.textMuted),const SizedBox(width:5),Text(v[0]+': ',style:const TextStyle(fontSize:9,color:AppColors.textSecondary)),Text(v[1],style:const TextStyle(fontSize:10,fontWeight:FontWeight.w700))])).toList()));
}
class _Empty extends StatelessWidget { final String text; const _Empty(this.text); @override Widget build(BuildContext c)=>Padding(padding:const EdgeInsets.symmetric(vertical:14),child:Text(text,style:const TextStyle(fontSize:10,color:AppColors.textMuted))); }
class _ProductStat { final String name; final int quantity; final double sales; const _ProductStat(this.name,this.quantity,this.sales); }
class _ClientStat { final String name; final int count; final double amount; const _ClientStat(this.name,this.count,this.amount); }
class _Dist { final String label; final double value; const _Dist(this.label,this.value); }

List<_ProductStat> _topProducts(List<SaleRecord> sales){final m=<String,List<dynamic>>{};for(final s in sales){if(s.isAnnulled)continue;for(final i in s.items){if(i.isElectronicBalance)continue;final k=i.productId.isEmpty?i.productName:i.productId;final v=m.putIfAbsent(k,()=>[i.productName,0,0.0]);v[1]+=i.quantity;v[2]+=i.lineTotal;}}final o=m.values.map((v)=>_ProductStat(v[0] as String,v[1] as int,v[2] as double)).toList()..sort((a,b)=>b.quantity.compareTo(a.quantity));return o.take(4).toList(growable:false);}
List<_ClientStat> _topClients(List<SaleRecord> sales){final m=<String,List<dynamic>>{};for(final s in sales){if(s.isAnnulled||s.clientId==null)continue;final k=s.clientId!;final v=m.putIfAbsent(k,()=>[s.clientName.trim().isEmpty?'Cliente':s.clientName.trim(),0,0.0]);v[1]++;v[2]+=s.effectiveTotal;}final o=m.values.map((v)=>_ClientStat(v[0] as String,v[1] as int,v[2] as double)).toList()..sort((a,b)=>b.amount.compareTo(a.amount));return o.take(4).toList(growable:false);}
List<_Dist> _paymentMix(List<SaleRecord> sales){final m=<String,double>{};for(final s in sales)if(!s.isAnnulled)m[s.paymentMethod]=(m[s.paymentMethod]??0)+s.effectiveTotal;final o=m.entries.map((e)=>_Dist(e.key,e.value)).toList()..sort((a,b)=>b.value.compareTo(a.value));return o.take(4).toList(growable:false);}
List<_Dist> _hourMix(List<SaleRecord> sales){final m=<String,double>{'06:00 - 12:00':0,'12:00 - 18:00':0,'18:00 - 22:00':0,'Otros horarios':0};for(final s in sales){if(s.isAnnulled)continue;final h=s.createdAt.hour;final k=h>=6&&h<12?'06:00 - 12:00':h>=12&&h<18?'12:00 - 18:00':h>=18&&h<22?'18:00 - 22:00':'Otros horarios';m[k]=(m[k]??0)+s.effectiveTotal;}final o=m.entries.where((e)=>e.value>0).map((e)=>_Dist(e.key,e.value)).toList()..sort((a,b)=>b.value.compareTo(a.value));return o;}
List<_Point> _trend(List<SaleRecord> sales,_StatsRange r){final m=<DateTime,double>{},labels=<DateTime,String>{};if(r.duration.inDays<=1){for(var d=r.start;d.isBefore(r.end);d=d.add(const Duration(hours:1))){final k=DateTime(d.year,d.month,d.day,d.hour);m[k]=0;labels[k]=d.hour.toString().padLeft(2,'0')+':00';}for(final s in sales)if(!s.isAnnulled&&r.contains(s.createdAt)){final k=DateTime(s.createdAt.year,s.createdAt.month,s.createdAt.day,s.createdAt.hour);m[k]=(m[k]??0)+s.effectiveTotal;}}else if(r.duration.inDays<=31){for(var d=r.start;d.isBefore(r.end);d=d.add(const Duration(days:1))){final k=DateTime(d.year,d.month,d.day);m[k]=0;labels[k]=d.day.toString()+'/${d.month.toString}'();}for(final s in sales)if(!s.isAnnulled&&r.contains(s.createdAt)){final k=DateTime(s.createdAt.year,s.createdAt.month,s.createdAt.day);m[k]=(m[k]??0)+s.effectiveTotal;}}else if(r.duration.inDays<=370){for(var d=r.start;d.isBefore(r.end);d=DateTime(d.year,d.month+1)){final k=DateTime(d.year,d.month);m[k]=0;labels[k]=_month(d.month).substring(0,3);}for(final s in sales)if(!s.isAnnulled&&r.contains(s.createdAt)){final k=DateTime(s.createdAt.year,s.createdAt.month);m[k]=(m[k]??0)+s.effectiveTotal;}}else{for(var d=r.start;d.isBefore(r.end);d=DateTime(d.year+1)){final k=DateTime(d.year);m[k]=0;labels[k]=d.year.toString();}for(final s in sales)if(!s.isAnnulled&&r.contains(s.createdAt)){final k=DateTime(s.createdAt.year);m[k]=(m[k]??0)+s.effectiveTotal;}}final e=m.entries.toList()..sort((a,b)=>a.key.compareTo(b.key));return e.map((x)=>_Point(labels[x.key]??'',x.value)).toList(growable:false);}
double _saleCost(SaleRecord s){if(s.isAnnulled)return 0;var c=s.items.fold<double>(0,(v,i)=>v+i.cost*i.quantity);for(final o in s.operations){c-=o.itemsOut.fold<double>(0,(v,i)=>v+i.cost*i.quantity);c+=o.itemsIn.fold<double>(0,(v,i)=>v+i.cost*i.quantity);}return math.max(0,c);}
double? _change(double a,double b)=>b.abs()<.005?null:(a-b)/b;
String _money(double v)=>'\$${v.toStringAsFixed}'(2);
String _pct(double v)=>(v*100).toStringAsFixed(1)+'%';
String _date(DateTime d)=>d.day.toString().padLeft(2,'0')+'/${d.month.toString}'().padLeft(2,'0')+'/${d.year.toString}'();
String _shortDate(DateTime d)=>d.day.toString().padLeft(2,'0')+'/${d.month.toString}'().padLeft(2,'0');
String _rangeLabel(_StatsRange r)=>_date(r.start)+' - ${_date}'(r.end.subtract(const Duration(days:1)));
String _month(int m)=>const ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'][m-1];
