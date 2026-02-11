// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Grow';

  @override
  String get locations => 'Locations';

  @override
  String get crops => 'Cultivations';

  @override
  String get records => 'Records';

  @override
  String get settings => 'Settings';

  @override
  String get addLocation => 'Add location';

  @override
  String get editLocation => 'Edit location';

  @override
  String get locationName => 'Location name';

  @override
  String get locationDescription => 'Description (optional)';

  @override
  String get plots => 'Plots';

  @override
  String get addPlot => 'Add plot';

  @override
  String get editPlot => 'Edit plot';

  @override
  String get plotName => 'Plot name';

  @override
  String get noPlots => 'No plots yet';

  @override
  String get selectPlot => 'Select plot (optional)';

  @override
  String get nonePlot => 'None';

  @override
  String get addCrop => 'Add cultivation';

  @override
  String get editCrop => 'Edit cultivation';

  @override
  String get cultivationName => 'Cultivation name';

  @override
  String get cropName => 'Crop name';

  @override
  String get variety => 'Variety';

  @override
  String get memo => 'Memo';

  @override
  String get addRecord => 'Add record';

  @override
  String get editRecord => 'Edit record';

  @override
  String get date => 'Date';

  @override
  String get note => 'Note';

  @override
  String get activityType => 'Activity';

  @override
  String get activitySowing => 'Sowing';

  @override
  String get activityTransplanting => 'Transplanting';

  @override
  String get activityWatering => 'Watering';

  @override
  String get activityObservation => 'Observation';

  @override
  String get activityHarvest => 'Harvest';

  @override
  String get activityOther => 'Other';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get deleteConfirm => 'Are you sure you want to delete this?';

  @override
  String get noLocations => 'No locations yet';

  @override
  String get noCrops => 'No cultivations yet';

  @override
  String get noRecords => 'No records yet';

  @override
  String get selectLocation => 'Select location';

  @override
  String get allLocations => 'All locations';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get lightMode => 'Light mode';

  @override
  String get systemMode => 'System default';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get pickFromGallery => 'Pick from gallery';

  @override
  String get photos => 'Photos';

  @override
  String get noPhotos => 'No photos yet';

  @override
  String get linkTarget => 'Link to';

  @override
  String get linkToLocation => 'Location';

  @override
  String get linkToPlot => 'Plot';

  @override
  String get linkToCrop => 'Cultivation';

  @override
  String get parentCrop => 'Parent cultivation';

  @override
  String get environmentType => 'Environment';

  @override
  String get envOutdoor => 'Outdoor';

  @override
  String get envIndoor => 'Indoor';

  @override
  String get envBalcony => 'Balcony';

  @override
  String get envRooftop => 'Rooftop';

  @override
  String get coverType => 'Cover type';

  @override
  String get coverOpen => 'Open (no cover)';

  @override
  String get coverGreenhouse => 'Greenhouse';

  @override
  String get coverTunnel => 'Tunnel';

  @override
  String get coverColdFrame => 'Cold frame';

  @override
  String get soilType => 'Soil type';

  @override
  String get soilUnknown => 'Unknown';

  @override
  String get soilCite => 'Clay';

  @override
  String get soilSilt => 'Silt';

  @override
  String get soilSandy => 'Sandy';

  @override
  String get soilLoam => 'Loam';

  @override
  String get soilPeat => 'Peat';

  @override
  String get soilVolcanic => 'Volcanic ash';

  @override
  String get getLocation => 'Get current location';

  @override
  String get locationSet => 'Location set';

  @override
  String get locationFailed => 'Could not get location';

  @override
  String get autoLinkNearest => 'Auto-select from current location';

  @override
  String get analyzing => 'Analyzing photo…';

  @override
  String get plantDetected => 'Plant detected';

  @override
  String get landscapeDetected => 'Landscape photo detected';

  @override
  String get noPlantDetected => 'No plant detected';

  @override
  String get identifyingPlant => 'Identifying plant…';

  @override
  String plantIdentified(String name) {
    return 'Estimated: $name';
  }

  @override
  String suggestedLink(String target) {
    return 'Suggested: $target';
  }

  @override
  String get apiKeyNotSet => 'Plant identification API key not set';

  @override
  String get plantIdProvider => 'Plant identification';

  @override
  String get plantIdProviderOff => 'Off (no identification)';

  @override
  String get plantIdProviderOffDesc => 'For small farms that don\'t need it';

  @override
  String get plantIdProviderPlantId => 'Plant.id (direct API)';

  @override
  String get plantIdProviderPlantIdDesc =>
      'Plant-specialized DB, low cost (200/month free)';

  @override
  String get plantIdProviderServer => 'Server (high accuracy)';

  @override
  String get plantIdProviderServerDesc => 'Claude / GPT-4V, can identify weeds';

  @override
  String get plantIdApiKey => 'Plant.id API Key';

  @override
  String get plantIdApiKeyHint => 'Enter API key';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get serverUrlHint => 'https://grow-server.example.workers.dev';

  @override
  String get serverToken => 'Auth token';

  @override
  String get serverTokenHint => 'Enter Bearer token';

  @override
  String get dataSync => 'Data sync';

  @override
  String get syncModeLocal => 'Local only';

  @override
  String get syncModeLocalDesc => 'Data stays on this device only';

  @override
  String get syncModeFastapi => 'FastAPI sync';

  @override
  String get syncModeFastapiDesc => 'Sync with local PC / shared server';

  @override
  String get syncModeCloudflare => 'Cloudflare sync';

  @override
  String get syncModeCloudflareDesc => 'Sync data and photos via server';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncing => 'Syncing…';

  @override
  String syncComplete(int pulled, int pushed, int photos) {
    return 'Sync complete (pulled: $pulled, pushed: $pushed, photos: $photos)';
  }

  @override
  String get syncFailed => 'Sync failed';

  @override
  String get plotDetail => 'Plot detail';

  @override
  String get cropsInPlot => 'Crops in this plot';

  @override
  String get noCropsInPlot => 'No crops in this plot yet';

  @override
  String get growthTimeline => 'Growth timeline';

  @override
  String get createHomepage => 'Create homepage';

  @override
  String get createHomepageDesc =>
      'Create a showcase page for this cultivation';

  @override
  String get homepageComingSoon => 'Homepage creation is coming soon';

  // Site creation screen
  @override
  String get siteInfoFarm => 'Farm info';
  @override
  String get siteFarmName => 'Farm name';
  @override
  String get siteFarmDesc => 'Farm description';
  @override
  String get siteFarmLocation => 'Location';
  @override
  String get siteFarmPolicy => 'Farming method (e.g. Natural farming)';
  @override
  String get siteInfoCrops => 'Crops to include';
  @override
  String get siteInfoSales => 'Sales info';
  @override
  String get siteSalesDesc => 'How to purchase';
  @override
  String get siteSalesContact => 'Contact (email, phone, etc.)';
  @override
  String get siteGenerate => 'Generate HTML';
  @override
  String get siteHtmlReady => 'HTML has been generated';
  @override
  String get siteCopyHtml => 'Copy HTML';
  @override
  String get siteDeploySection => 'Auto-deploy to Cloudflare';
  @override
  String get siteDeployDesc => 'Deploy directly to Cloudflare Pages. Requires Account ID and API Token.';
  @override
  String get siteCfAccountId => 'Cloudflare Account ID';
  @override
  String get siteCfApiToken => 'Cloudflare API Token';
  @override
  String get siteCfProjectName => 'Project name (site URL)';
  @override
  String get siteDeploy => 'Deploy';
  @override
  String get siteDeployDone => 'Deployed successfully';

  @override
  String get searchRecords => 'Search records';

  @override
  String get filterByActivity => 'Filter by activity';

  @override
  String get allActivities => 'All activities';

  @override
  String get searchHint => 'Search by note, crop, or location';

  @override
  String get cultivationInfo => 'Cultivation info';

  @override
  String get seedPacketPhotos => 'Seed packet photos';

  @override
  String get readFromUrl => 'Get info from URL';

  @override
  String get readFromSeedPhoto => 'Read from seed packet photo';

  @override
  String get saveSeedPhoto => 'Save seed packet photo (local)';

  @override
  String get cultivationReferences => 'References';

  @override
  String get addReference => 'Add reference URL';

  @override
  String get referenceUrl => 'URL';

  @override
  String get referenceTitle => 'Title';

  @override
  String get noReferences => 'No references yet';

  @override
  String get readingUrl => 'Reading info from URL…';

  @override
  String get readingImage => 'Reading seed packet…';

  @override
  String get readSuccess => 'Cultivation info retrieved';

  @override
  String get readFailed => 'Failed to retrieve info';

  @override
  String get serverRequired => 'Server configuration required for this feature';

  @override
  String get autoFillConfirm => 'Auto-fill crop name and variety?';

  @override
  String get sowingPeriod => 'Sowing period';

  @override
  String get harvestPeriod => 'Harvest period';

  @override
  String get spacing => 'Spacing';

  @override
  String get seedDepth => 'Seed depth';

  @override
  String get sunlight => 'Sunlight';

  @override
  String get fertilizerInfo => 'Fertilizer';

  @override
  String get cultivationTips => 'Growing tips';

  @override
  String get sourceUrl => 'Source URL';

  @override
  String get cachedInfo => '(from shared database)';

  @override
  String get skill => 'Skill';

  @override
  String get farmingMethod => 'Farming method';

  @override
  String get inheritFromSkill => 'Use skill defaults';
}
