/// Source of a logged set
enum SetSource {
  app,
  liveActivity;

  String get value {
    switch (this) {
      case SetSource.app:
        return 'app';
      case SetSource.liveActivity:
        return 'liveActivity';
    }
  }

  static SetSource fromString(String value) {
    switch (value) {
      case 'liveActivity':
        return SetSource.liveActivity;
      default:
        return SetSource.app;
    }
  }
}

/// Weight unit preference
enum WeightUnit {
  kg,
  lb;

  String get label {
    switch (this) {
      case WeightUnit.kg:
        return 'kg';
      case WeightUnit.lb:
        return 'lb';
    }
  }

  double get defaultIncrement {
    switch (this) {
      case WeightUnit.kg:
        return 2.5;
      case WeightUnit.lb:
        return 5.0;
    }
  }

  static WeightUnit fromString(String value) {
    switch (value) {
      case 'lb':
        return WeightUnit.lb;
      default:
        return WeightUnit.kg;
    }
  }
}
