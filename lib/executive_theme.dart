import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// An elite, ultra-premium executive theme styled after luxury corporate brands like BMW, Mercedes-Benz, and Jaguar.
/// Employs a stunning "Obsidian & Satin Champagne Gold / Roasted Cognac" color palette.
/// Fully configurable, serving as the single source of truth for all application colors.
class ExecutiveTheme {
  // ==========================================
  // 1. SYSTEM COLOR PALETTE DEFINITIONS
  // ==========================================

  // --- DARK THEME TOKENS (Premium Executive Obsidian) ---
  static const Color darkScaffoldBg = Color(0xFF09090B);      // Pure Executive Obsidian Black
  static const Color darkCardBg = Color(0xFF141416);          // Sleek Anthracite Carbon Card
  static const Color darkCardBorder = Color(0xFF222225);      // Polished Titanium border
  static const Color darkPrimaryGold = Color(0xFFD4B170);     // Radiant Satin Champagne Gold
  static const Color darkAccentCognac = Color(0xFFC5A059);    // Brushed Cognac Amber Gold
  static const Color darkTextPrimary = Color(0xFFF4F4F5);     // Satin Alabaster White
  static const Color darkTextSecondary = Color(0xFF94A3B8);   // Muted Sterling Silver Slate

  // --- LIGHT THEME TOKENS (Elite Executive Office - HIGH CONTRAST) ---
  static const Color lightScaffoldBg = Color(0xFFF4F3F0);     // Elegant Satin Ivory Cashmere (sharp background contrast)
  static const Color lightCardBg = Color(0xFFFFFFFF);         // High-gloss Pure Marble White (sharp bubble contrast)
  static const Color lightCardBorder = Color(0xFFD1D5DB);     // Crisp Polished Satin Silver border
  static const Color lightPrimaryObsidian = Color(0xFF111115); // Deep Matte Obsidian Charcoal
  static const Color lightAccentGold = Color(0xFF5F4517);      // Deep Roasted Cognac Gold (WCAG AAA compliant dark gold/bronze)
  static const Color lightTextPrimary = Color(0xFF0F172A);    // Razor Sharp Executive Ink Slate
  static const Color lightTextSecondary = Color(0xFF475569);  // Charcoal Silver Slate (sharper body/descriptions)

  // --- UNIVERSAL STATE ACCENTS ---
  static const Color successGreen = Color(0xFF10B981); // Emerald Green
  static const Color warningAmber = Color(0xFFF59E0B); // Radiant Amber
  static const Color errorRed = Color(0xFFEF4444);     // Crimson Red

  // ==========================================
  // 2. DETAILED MARKDOWN & CHAT SUB-COLORS
  // ==========================================

  // --- BLOCKQUOTE COMPONENT ---
  static const Color darkBlockquoteBg = Color(0xFF1B160F);
  static const Color darkBlockquoteBorder = Color(0xFFC5A059);
  static const Color darkBlockquoteText = Color(0xFFD4B170);

  static const Color lightBlockquoteBg = Color(0xFFFAF7F2);     // Luxe Soft Cream Champagne
  static const Color lightBlockquoteBorder = Color(0xFF5F4517); // Deep Roasted Cognac
  static const Color lightBlockquoteText = Color(0xFF5F4517);   // Deep Roasted Cognac

  // --- CODE & INLINE HIGHLIGHTING ---
  static const Color darkCodeBg = Color(0xFF1B160F);
  static const Color darkCodeText = Color(0xFFE6C697);
  static const Color lightCodeBg = Color(0xFFFAF7F2);
  static const Color lightCodeText = Color(0xFF5F4517);

  // --- TABLES ---
  static const Color darkTableBorder = Color(0xFF222225);
  static const Color lightTableBorder = Color(0xFFCBD5E1);
  static const Color darkTableHeaderText = Color(0xFFD4B170);
  static const Color lightTableHeaderText = Color(0xFF5F4517); // High contrast dark cognac gold

  // --- CODE BLOCKS ---
  static const Color darkCodeBlockBg = Color(0xFF141416);
  static const Color darkCodeBlockBorder = Color(0xFF222225);
  static const Color lightCodeBlockBg = Color(0xFFF1F5F9);
  static const Color lightCodeBlockBorder = Color(0xFFCBD5E1);

  // --- CHAT INPUT BAR ---
  static const Color darkInputBarBg = Color(0xFF09090B);      // Pure Obsidian Black (seamless screen-merge)
  static const Color darkInputBarBorder = Color(0xFF141416);  // Polished Titanium border line
  static const Color darkInputFill = Color(0xFF141416);       // Sleek Carbon Card fill (stands out slightly as a pill)

  static const Color lightInputBarBg = Color(0xFFFFFFFF);     // High-gloss Pure Marble White
  static const Color lightInputBarBorder = Color(0xFFE2E8F0); // Subtle silver-grey border
  static const Color lightInputFill = Color(0xFFF1F5F9);      // Gentle satin grey inner fill

  // --- EMPTY STATE GRADIENTS ---
  static const List<Color> darkEmptyStateColors = [Color(0xFF09090B), Color(0xFF0F0C08), Color(0xFF1B160F)];
  static const List<Color> lightEmptyStateColors = [Color(0xFFFAFAFB), Color(0xFFF3F1ED), Color(0xFFE9E5DE)];

  // --- USER CHAT BUBBLE GRADIENTS ---
  static const List<Color> darkUserBubbleColors = [Color(0xFFE6C697), Color(0xFFC5A059)]; // Gold Metallic
  static const List<Color> lightUserBubbleColors = [Color(0xFF111115), Color(0xFF2E2E35)]; // Obsidian Black

  // --- LOADING FLUID LINE GRADIENT ---
  static const List<Color> loadingFluidColors = [
    Color(0xFFD4B170), // Satin Champagne Gold
    Color(0xFFC5A059), // Brushed Cognac Amber
    Color(0xFFE2E8F0), // Polished Platinum Silver
    Color(0xFF5F4517), // Deep Roasted Cognac Gold
    Color(0xFFD4B170), // Satin Champagne Gold
  ];

  // --- KNOWLEDGE BASE / CATALOG BADGES ---
  // Alpha (Tiger Catalog)
  static const Color darkAlphaBg = Color(0xFF1F1A12);           // Deep premium amber/gold ambient tint
  static const Color darkAlphaBorder = Color(0xFF423525);       // Subtle gold accent border
  static const Color darkAlphaText = Color(0xFFD4B170);         // Radiant champagne gold
  static const Color lightAlphaBg = Color(0xFFFEF3C7);          // Warm champagne cream
  static const Color lightAlphaBorder = Color(0xFFFDE68A);      // Soft gold/sand border
  static const Color lightAlphaText = Color(0xFF5F4517);        // Deep roasted cognac (extremely readable)

  // Beta (RX Catalog / General)
  static const Color darkBetaBg = Color(0xFF141416);            // Carbon anthracite card
  static const Color darkBetaBorder = Color(0xFF222225);        // Polished titanium
  static const Color darkBetaText = Color(0xFFE2E8F0);          // Polished platinum
  static const Color lightBetaBg = Color(0xFFF1F5F9);           // Crisp metallic silver-blue
  static const Color lightBetaBorder = Color(0xFFCBD5E1);       // Polished silver-slate
  static const Color lightBetaText = Color(0xFF334155);         // Deep slate slate ink

  // Match / Score Badge (Success Green Accent)
  static const Color darkMatchBg = Color(0xFF0C201A);           // Forest emerald deep
  static const Color darkMatchBorder = Color(0xFF104E37);       // Emerald border
  static const Color darkMatchText = Color(0xFF34D399);         // Light mint green
  static const Color lightMatchBg = Color(0xFFECFDF5);          // Ultra soft mint
  static const Color lightMatchBorder = Color(0xFFA7F3D0);      // Soft emerald border
  static const Color lightMatchText = Color(0xFF047857);        // Deep pine green

  // View Source button
  static const Color darkViewSourceBg = Color(0xFF1B160F);
  static const Color darkViewSourceBorder = Color(0xFF423525);
  static const Color darkViewSourceText = Color(0xFFD4B170);
  static const Color lightViewSourceBg = Color(0xFFFEF3C7);     // Warm champagne cream
  static const Color lightViewSourceBorder = Color(0xFFFDE68A); // Soft gold border
  static const Color lightViewSourceText = Color(0xFF5F4517);   // Deep roasted cognac

  // ==========================================
  // 3. LUXURY GRADIENTS
  // ==========================================

  /// Glowing metallic Gold/Champagne gradient
  static const LinearGradient premiumGoldGradient = LinearGradient(
    colors: darkUserBubbleColors,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Deep luxurious ambient dark gold gradient for containers & backgrounds
  static const LinearGradient ambientGoldGradient = LinearGradient(
    colors: [Color(0xFF1F1A12), Color(0xFF0C0905)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Polished silver/platinum metallic gradient
  static const LinearGradient premiumSilverGradient = LinearGradient(
    colors: [Color(0xFFE2E8F0), Color(0xFF94A3B8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Executive deep background gradient
  static const LinearGradient darkBgGradient = LinearGradient(
    colors: [Color(0xFF0E0E11), Color(0xFF050507)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ==========================================
  // 4. THEMEDATA GENERATORS
  // ==========================================

  /// Builds the light executive theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: lightPrimaryObsidian,
      scaffoldBackgroundColor: lightScaffoldBg,
      cardColor: lightCardBg,
      hintColor: lightTextSecondary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: lightAccentGold,
        brightness: Brightness.light,
        primary: lightPrimaryObsidian,
        secondary: lightAccentGold,
        surface: lightCardBg,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: lightTextPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: lightTextPrimary,
          letterSpacing: -0.2,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: lightTextPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: lightTextSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightPrimaryObsidian,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: const CardThemeData(
        color: lightCardBg,
        elevation: 3,
        shadowColor: Color(0x1F000000), // Slightly more crisp, sharp shadows for clear card depth
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: lightCardBorder, width: 1.2), // Sharper outline
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimaryObsidian,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  /// Builds the dark executive theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: darkPrimaryGold,
      scaffoldBackgroundColor: darkScaffoldBg,
      cardColor: darkCardBg,
      hintColor: darkTextSecondary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkPrimaryGold,
        brightness: Brightness.dark,
        primary: darkPrimaryGold,
        secondary: darkAccentCognac,
        surface: darkCardBg,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          letterSpacing: -0.2,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: darkTextPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: darkTextSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkScaffoldBg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: const CardThemeData(
        color: darkCardBg,
        elevation: 4,
        shadowColor: Color(0x33000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: darkCardBorder, width: 1.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimaryGold,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
