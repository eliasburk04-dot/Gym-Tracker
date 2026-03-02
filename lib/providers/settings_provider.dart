import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/enums.dart';

/// User settings
class SettingsState {
  final WeightUnit weightUnit;
  final double weightIncrement;

  const SettingsState({
    this.weightUnit = WeightUnit.kg,
    this.weightIncrement = 2.5,
  });

  SettingsState copyWith({WeightUnit? weightUnit, double? weightIncrement}) {
    return SettingsState(
      weightUnit: weightUnit ?? this.weightUnit,
      weightIncrement: weightIncrement ?? this.weightIncrement,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final unitStr = prefs.getString('weight_unit') ?? 'kg';
    final unit = WeightUnit.fromString(unitStr);
    final increment = prefs.getDouble('weight_increment') ?? unit.defaultIncrement;
    state = SettingsState(weightUnit: unit, weightIncrement: increment);
  }

  Future<void> setWeightUnit(WeightUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weight_unit', unit.label);
    state = state.copyWith(
      weightUnit: unit,
      weightIncrement: unit.defaultIncrement,
    );
  }

  Future<void> setWeightIncrement(double increment) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('weight_increment', increment);
    state = state.copyWith(weightIncrement: increment);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

/// Convenient accessor for weight increment
final weightIncrementProvider = Provider<double>((ref) {
  return ref.watch(settingsProvider).weightIncrement;
});

/// Convenient accessor for weight unit
final weightUnitProvider = Provider<WeightUnit>((ref) {
  return ref.watch(settingsProvider).weightUnit;
});
