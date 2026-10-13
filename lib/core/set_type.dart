/// Typ serie v workoutu.
///
/// Kazda serie muze byt normalni, zahrevaci (W), do padnuti (F)
/// nebo drop set ( D). Uklada se do DB jako retezec.
class SetType {
  static const normal = 'normal';
  static const warmup = 'warmup';
  static const failure = 'failure';
  static const dropSet = 'drop_set';

  /// Mapa: hodnota v DB -> popisek v menu.
  static const labels = {
    normal: 'Normal set',
    warmup: 'Warmup (W)',
    failure: 'Failure (F)',
    dropSet: 'Drop set (D)',
  };

  /// Vrati zkratku pro zobrazeni v krouzku u serie:
  /// normalni serie = cislo, jinak pismenko.
  static String indicator(String setType, int setNumber) {
    switch (setType) {
      case warmup:
        return 'W';
      case failure:
        return 'F';
      case dropSet:
        return 'D';
      default:
        return '$setNumber';
    }
  }
}
