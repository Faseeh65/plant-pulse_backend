# Graph Report - Plant Pulse FYP  (2026-04-25)

## Corpus Check
- 55 files · ~247,713 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 543 nodes · 622 edges · 30 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 2 edges (avg confidence: 0.5)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 26 edges
2. `package:supabase_flutter/supabase_flutter.dart` - 12 edges
3. `package:provider/provider.dart` - 10 edges
4. `../utils/string_extensions.dart` - 7 edges
5. `../services/api_service.dart` - 7 edges
6. `RiceInferenceEngine` - 6 edges
7. `../providers/locale_provider.dart` - 6 edges
8. `dart:ui` - 6 edges
9. `dart:io` - 6 edges
10. `../services/database_service.dart` - 5 edges

## Surprising Connections (you probably didn't know these)
- `Returns treatment data formatted for the Flutter DiseaseResult model.     Syncs` --uses--> `RiceInferenceEngine`  [INFERRED]
  backend\main.py → backend\inference_server.py
- `HistorySave` --uses--> `RiceInferenceEngine`  [INFERRED]
  backend\main.py → backend\inference_server.py

## Communities

### Community 0 - "Community 0"
Cohesion: 0.04
Nodes (47): build, _buildBottomBar, _captureAndAnalyze, Center, Container, CustomPaint, dispose, Divider (+39 more)

### Community 1 - "Community 1"
Cohesion: 0.06
Nodes (34): ApiService, build, _buildActionTile, _buildAnalysisFrame, _buildAnimatedSection, _buildCrosshairs, _buildDualReportBox, _buildEnvironmentalSection (+26 more)

### Community 2 - "Community 2"
Cohesion: 0.06
Nodes (31): build, HomeScreen, LanguageToggle, Scaffold, SizedBox, Spacer, build, Container (+23 more)

### Community 3 - "Community 3"
Cohesion: 0.07
Nodes (27): LocaleProvider, ThemeProvider, toggleTheme, AnimatedContainer, AuthScreen, _AuthScreenState, build, _buildGlassCard (+19 more)

### Community 4 - "Community 4"
Cohesion: 0.06
Nodes (32): build, _buildAnimatedThemeToggle, _buildDrawerButton, _buildDrawerItem, _buildFloatingDock, _buildHeroScanZone, _buildIntelligenceCarousel, _buildNavigationDrawer (+24 more)

### Community 5 - "Community 5"
Cohesion: 0.06
Nodes (31): AnimatedBuilder, build, _buildDosageCalculator, _buildEmptyState, _buildErrorState, _buildHeader, _buildLoadingState, _buildMarketSection (+23 more)

### Community 6 - "Community 6"
Cohesion: 0.06
Nodes (29): build, _buildAnimatedHistoryCard, _buildEmptyState, _buildHistoryCard, Center, Container, dispose, HistoryScreen (+21 more)

### Community 7 - "Community 7"
Cohesion: 0.07
Nodes (27): _applyFilters, _getHueForDisease, MapProvider, Marker, setFilter, build, _buildActionableAdvice, _buildDiseaseFilter (+19 more)

### Community 8 - "Community 8"
Cohesion: 0.07
Nodes (25): build, CustomPaint, dispose, FadeTransition, initState, paint, _Particle, _ParticlesPainter (+17 more)

### Community 9 - "Community 9"
Cohesion: 0.08
Nodes (25): AuthService, build, dispose, _divider, _editableField, GestureDetector, initState, InkWell (+17 more)

### Community 10 - "Community 10"
Cohesion: 0.08
Nodes (25): ApiService, build, _buildList, Center, Container, _countdown, _createReminder, _dlgField (+17 more)

### Community 11 - "Community 11"
Cohesion: 0.08
Nodes (25): AxisTitles, BarChartGroupData, BarTooltipItem, build, _buildBarChart, _buildContent, _cardWrap, Center (+17 more)

### Community 12 - "Community 12"
Cohesion: 0.08
Nodes (25): Align, AnimatedBuilder, AppBar, build, _buildCameraPreview, _buildScanOverlay, _buildShutterButton, _buildTransparentAppBar (+17 more)

### Community 13 - "Community 13"
Cohesion: 0.08
Nodes (22): build, MaterialApp, PlantPulseApp, AuthService, DatabaseService, _trySync, local_db_service.dart, package:supabase_flutter/supabase_flutter.dart (+14 more)

### Community 14 - "Community 14"
Cohesion: 0.09
Nodes (20): WeatherProvider, build, _buildAgriAlert, _buildLoading, _buildWeatherCard, Color, Column, Container (+12 more)

### Community 15 - "Community 15"
Cohesion: 0.11
Nodes (17): app_localizations.dart, app_localizations_en.dart, app_localizations_ur.dart, AppLocalizations, _AppLocalizationsDelegate, AppLocalizationsEn, AppLocalizationsUr, FlutterError (+9 more)

### Community 16 - "Community 16"
Cohesion: 0.16
Nodes (5): BaseModel, RiceInferenceEngine, get_treatment(), HistorySave, Returns treatment data formatted for the Flutter DiseaseResult model.     Syncs

### Community 17 - "Community 17"
Cohesion: 0.25
Nodes (7): AndroidNotificationChannel, NotificationService, _onNotificationTap, package:flutter_local_notifications/flutter_local_notifications.dart, package:permission_handler/permission_handler.dart, package:timezone/data/latest_all.dart, package:timezone/timezone.dart

### Community 18 - "Community 18"
Cohesion: 0.33
Nodes (5): isValid, ScanGuard, toString, UnrecognizedScanException, validate

### Community 19 - "Community 19"
Cohesion: 0.5
Nodes (1): AttributionIdInitializer

### Community 20 - "Community 20"
Cohesion: 0.5
Nodes (1): MainActivity

### Community 21 - "Community 21"
Cohesion: 0.5
Nodes (3): CausalRule, DiagnosticQuestion, RefinedResult

### Community 22 - "Community 22"
Cohesion: 0.67
Nodes (1): GeneratedPluginRegistrant

### Community 23 - "Community 23"
Cohesion: 0.67
Nodes (2): DiseaseResult, MarketRecommendation

### Community 24 - "Community 24"
Cohesion: 0.67
Nodes (2): MarketProduct, TreatmentSolution

### Community 25 - "Community 25"
Cohesion: 0.67
Nodes (2): main, package:flutter_test/flutter_test.dart

### Community 27 - "Community 27"
Cohesion: 1.0
Nodes (1): MapMarkerData

### Community 28 - "Community 28"
Cohesion: 1.0
Nodes (1): WeatherData

### Community 29 - "Community 29"
Cohesion: 1.0
Nodes (1): AppAssets

### Community 30 - "Community 30"
Cohesion: 1.0
Nodes (1): AppConstants

## Knowledge Gaps
- **428 isolated node(s):** `PlantPulseApp`, `build`, `MaterialApp`, `screens/auth_screen.dart`, `screens/home_screen.dart` (+423 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 19`** (4 nodes): `AttributionIdInitializer.kt`, `AttributionIdInitializer`, `.create()`, `.dependencies()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 20`** (4 nodes): `MainActivity.kt`, `MainActivity`, `.onCreate()`, `.onMapsSdkInitialized()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 22`** (3 nodes): `GeneratedPluginRegistrant.java`, `GeneratedPluginRegistrant`, `.registerWith()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 23`** (3 nodes): `DiseaseResult`, `MarketRecommendation`, `disease_result.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 24`** (3 nodes): `MarketProduct`, `TreatmentSolution`, `treatment.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 25`** (3 nodes): `main`, `package:flutter_test/flutter_test.dart`, `widget_test.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 27`** (2 nodes): `MapMarkerData`, `map_marker_data.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 28`** (2 nodes): `WeatherData`, `weather_data.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 29`** (2 nodes): `AppAssets`, `app_assets.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 30`** (2 nodes): `AppConstants`, `constants.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Community 3` to `Community 0`, `Community 1`, `Community 2`, `Community 4`, `Community 5`, `Community 6`, `Community 7`, `Community 8`, `Community 9`, `Community 10`, `Community 11`, `Community 12`, `Community 13`, `Community 14`, `Community 17`?**
  _High betweenness centrality (0.398) - this node is a cross-community bridge._
- **Why does `package:supabase_flutter/supabase_flutter.dart` connect `Community 13` to `Community 0`, `Community 1`, `Community 3`, `Community 6`, `Community 8`, `Community 9`, `Community 10`, `Community 11`?**
  _High betweenness centrality (0.091) - this node is a cross-community bridge._
- **Why does `package:provider/provider.dart` connect `Community 2` to `Community 1`, `Community 4`, `Community 5`, `Community 7`, `Community 9`, `Community 13`, `Community 14`?**
  _High betweenness centrality (0.056) - this node is a cross-community bridge._
- **What connects `PlantPulseApp`, `build`, `MaterialApp` to the rest of the system?**
  _428 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.04 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._