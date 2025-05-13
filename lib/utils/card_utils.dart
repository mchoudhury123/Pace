class CardUtils {
  static String getCardTypeFrmNumber(String input) {
    CardType cardType;
    if (input.isEmpty) {
      return "Unknown";
    }

    cardType = _getCardTypeFrmNumber(input);
    
    switch (cardType) {
      case CardType.visa:
        return "Visa";
      case CardType.mastercard:
        return "Mastercard";
      case CardType.amex:
        return "American Express";
      case CardType.discover:
        return "Discover";
      case CardType.dinersclub:
        return "Diners Club";
      case CardType.jcb:
        return "JCB";
      default:
        return "Unknown";
    }
  }

  static CardType _getCardTypeFrmNumber(String input) {
    // Remove all non-digit characters
    final cleanNumber = input.replaceAll(RegExp(r'\D'), '');
    
    // Visa: Starts with 4
    if (cleanNumber.startsWith('4')) {
      return CardType.visa;
    }
    
    // Mastercard: Starts with 51-55 or 2221-2720
    if ((cleanNumber.startsWith('51') || 
         cleanNumber.startsWith('52') || 
         cleanNumber.startsWith('53') || 
         cleanNumber.startsWith('54') || 
         cleanNumber.startsWith('55')) || 
        (cleanNumber.length >= 4 && 
         int.parse(cleanNumber.substring(0, 4)) >= 2221 && 
         int.parse(cleanNumber.substring(0, 4)) <= 2720)) {
      return CardType.mastercard;
    }
    
    // American Express: Starts with 34 or 37
    if (cleanNumber.startsWith('34') || cleanNumber.startsWith('37')) {
      return CardType.amex;
    }
    
    // Discover: Starts with 6011, 622126-622925, 644-649, or 65
    if (cleanNumber.startsWith('6011') || 
        (cleanNumber.length >= 6 && 
         int.parse(cleanNumber.substring(0, 6)) >= 622126 && 
         int.parse(cleanNumber.substring(0, 6)) <= 622925) || 
        (cleanNumber.startsWith('644') || 
         cleanNumber.startsWith('645') || 
         cleanNumber.startsWith('646') || 
         cleanNumber.startsWith('647') || 
         cleanNumber.startsWith('648') || 
         cleanNumber.startsWith('649')) || 
        cleanNumber.startsWith('65')) {
      return CardType.discover;
    }
    
    // Diners Club: Starts with 300-305, 36, or 38-39
    if ((cleanNumber.length >= 3 && 
         int.parse(cleanNumber.substring(0, 3)) >= 300 && 
         int.parse(cleanNumber.substring(0, 3)) <= 305) || 
        cleanNumber.startsWith('36') || 
        cleanNumber.startsWith('38') || 
        cleanNumber.startsWith('39')) {
      return CardType.dinersclub;
    }
    
    // JCB: Starts with 2131, 1800, or 35
    if (cleanNumber.startsWith('2131') || 
        cleanNumber.startsWith('1800') || 
        cleanNumber.startsWith('35')) {
      return CardType.jcb;
    }
    
    return CardType.unknown;
  }
}

enum CardType {
  visa,
  mastercard,
  amex,
  discover,
  dinersclub,
  jcb,
  unknown,
} 