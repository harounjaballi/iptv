import '../../models/category_model.dart';
import '../../models/episode_item.dart';
import '../../models/live_channel.dart';
import '../../models/series_details.dart';
import '../../models/series_item.dart';
import '../../models/vod_details.dart';
import '../../models/vod_item.dart';
import '../../models/xtream_credentials.dart';

/// Contrat d'accès au contenu (couche domaine).
abstract interface class ContentRepository {
  Future<List<CategoryModel>> liveCategories(XtreamCredentials c);
  Future<List<CategoryModel>> vodCategories(XtreamCredentials c);
  Future<List<CategoryModel>> seriesCategories(XtreamCredentials c);
  Future<List<LiveChannel>> liveChannels(XtreamCredentials c, {String? categoryId});
  Future<List<VodItem>> movies(XtreamCredentials c, {String? categoryId});
  Future<List<SeriesItem>> series(XtreamCredentials c, {String? categoryId});
  Future<List<EpisodeItem>> episodes(XtreamCredentials c, int seriesId);
  Future<VodDetails> vodDetails(XtreamCredentials c, int streamId);
  Future<SeriesDetails> seriesDetails(XtreamCredentials c, int seriesId);
}
