import 'package:blyft/controller/cubit/theme/theme_cubit.dart';
import 'package:blyft/controller/cubit/theme/theme_state.dart';
import 'package:blyft/controller/services/news_services.dart';
import 'package:blyft/models/article_model.dart';
import 'package:blyft/models/news_category.dart';
import 'package:blyft/utils/logger.dart';
import 'package:blyft/views/common_widgets/common_appbar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:blyft/l10n/app_localizations.dart';

import '../../controller/cubit/user_profile/user_profile_cubit.dart';
import '../../controller/cubit/user_profile/user_profile_state.dart';

class SidePage extends StatefulWidget {
  const SidePage({super.key});

  @override
  State<SidePage> createState() => _SidePageState();
}

class _SidePageState extends State<SidePage> with TickerProviderStateMixin {
  final NewsService _newsService = NewsService();
  late Future<List<Article>> _topNewsFuture;
  final TextEditingController _searchController = TextEditingController();
  late Animation<double> _animation;
  late AnimationController _animationController;
  late AnimationController _particleAnimationController;

  @override
  void initState() {
    super.initState();
    Log.i('SIDE_PAGE: Screen started');
    _topNewsFuture = _newsService.fetchGeneralNews(page: 1, pageSize: 3);

    context.read<UserProfileCubit>().loadUserProfile();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _particleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _particleAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _hasProfileImage(UserProfileState state, user) {
    return state.localProfileImage != null ||
        (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty);
  }

  ImageProvider? _getProfileImage(UserProfileState state, user) {
    if (state.localProfileImage != null) {
      return FileImage(state.localProfileImage!);
    }
    if (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty) {
      return NetworkImage(user.profileImageUrl!);
    }
    return null;
  }

  void _handleSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseEnterSearchQuery)),
      );
      return;
    }
    Log.i('SIDE_PAGE: Navigating to SearchResults with query: $query');
    context.pushNamed('searchResults', queryParameters: {'query': query});
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);

    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, themeState) {
        final currentTheme = themeState.currentTheme;

        return GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! < -5) {
              Log.i('SIDE_PAGE: Navigating to Home via swipe gesture');
              context.goNamed(
                'home',
                pathParameters: {
                  'category': NewsCategory.general.index.toString(),
                },
              );
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: theme.colorScheme.surface.withAlpha(
                    (0.85 * 255).toInt(),
                  ),
                  expandedHeight: 155,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: ParticlesHeader(
                      title: "",
                      themeColor: currentTheme.primaryColor,
                      particleAnimation: _particleAnimationController,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                BlocBuilder<UserProfileCubit, UserProfileState>(
                                  builder: (context, state) {
                                    return CircleAvatar(
                                      radius: 24,
                                      backgroundColor:
                                          _hasProfileImage(state, state.user)
                                              ? Colors.transparent
                                              : theme.colorScheme.primary,
                                      backgroundImage: _getProfileImage(
                                        state,
                                        state.user,
                                      ),
                                      child: InkWell(
                                        onTap: () {
                                          Log.i('SIDE_PAGE: Navigating to Profile');
                                          context.push("/sidepage/profile");
                                        },
                                        child:
                                            !_hasProfileImage(state, state.user)
                                                ? Icon(
                                                  Icons.person,
                                                  size: 28,
                                                  color:
                                                      theme
                                                          .colorScheme
                                                          .onSecondaryContainer,
                                                )
                                                : null,
                                      ),
                                    );
                                  },
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () {
                                    Log.i('SIDE_PAGE: MY FEED button tapped - Navigating to Home');
                                    context.goNamed(
                                      'home',
                                      pathParameters: {
                                        'category':
                                            NewsCategory.general.index
                                                .toString(),
                                      },
                                    );
                                  },
                                  icon: Text(
                                      AppLocalizations.of(context)!.myFeed.toUpperCase(),
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  label: Icon(
                                    Icons.arrow_forward,
                                    size: 18,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _searchController,
                              style: theme.textTheme.bodyLarge,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: AppLocalizations.of(context)!.searchNewsTopics,
                                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurface.withAlpha(
                                    (0.6 * 255).toInt(),
                                  ),
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.search),
                                  color: theme.colorScheme.onSurface.withAlpha(
                                    (0.7 * 255).toInt(),
                                  ),
                                  onPressed: _handleSearch,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: theme
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha((0.7 * 255).toInt()),
                              ),
                              onSubmitted: (_) {
                                Log.i('SIDE_PAGE: Search submitted via keyboard');
                                _handleSearch();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          currentTheme.primaryColor.withAlpha(
                            (0.1 * 255).toInt(),
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: FadeTransition(
                      opacity: _animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.1),
                          end: Offset.zero,
                        ).animate(_animation),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 100,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  shrinkWrap: true,
                                  children: [
                                    _buildMenuButton(
                                      AppLocalizations.of(context)!.myFeed,
                                      Icons.home,
                                      context,
                                      NewsCategory.general,
                                      currentTheme.primaryColor,
                                    ),
                                    _buildMenuButton(
                                      AppLocalizations.of(context)!.topStories,
                                      Icons.trending_up,
                                      context,
                                      NewsCategory.general,
                                      currentTheme.primaryColor,
                                    ),
                                    _buildMenuButton(
                                      AppLocalizations.of(context)!.bookmarks,
                                      Icons.bookmark,
                                      context,
                                      null,
                                      currentTheme.primaryColor,
                                    ),
                                    _buildMenuButton(
                                      AppLocalizations.of(context)!.settings,
                                      Icons.settings,
                                      context,
                                      null,
                                      currentTheme.primaryColor,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                AppLocalizations.of(context)!.topNews.toUpperCase(),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              FutureBuilder<List<Article>>(
                                future: _topNewsFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Column(
                                      children: List.generate(
                                        3,
                                        (index) =>
                                            _buildNewsItem(context, null),
                                      ),
                                    );
                                  }
                                  if (snapshot.hasError) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Text(
                                        AppLocalizations.of(context)!.failedToLoadTopNews,
                                        style: TextStyle(
                                          fontSize: textScaler.scale(14),
                                          color: theme.colorScheme.error,
                                        ),
                                      ),
                                    );
                                  }
                                  return Column(
                                    children:
                                        snapshot.data!
                                            .map(
                                              (article) => _buildNewsItem(
                                                context,
                                                article,
                                              ),
                                            )
                                            .toList(),
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                              Text(
                                AppLocalizations.of(context)!.topics.toUpperCase(),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.65,
                                padding: EdgeInsets.zero,
                                children: [
                                  _buildImageContainer(
                                    AppLocalizations.of(context)!.technology,
                                    'https://i.pinimg.com/736x/6b/8e/97/6b8e974572105a1e4096c1a8e2b6a7bc.jpg',
                                    context,
                                    NewsCategory.technology,
                                  ),
                                  _buildImageContainer(
                                    AppLocalizations.of(context)!.politics,
                                    'https://i.pinimg.com/736x/f2/c0/9c/f2c09c8daf5c64c92ea5738507f4ed26.jpg',
                                    context,
                                    NewsCategory.politics,
                                  ),
                                  _buildImageContainer(
                                    AppLocalizations.of(context)!.sports,
                                    'https://i.pinimg.com/736x/fe/67/49/fe674914b51da2170019d092e19f5440.jpg',
                                    context,
                                    NewsCategory.sports,
                                  ),
                                  _buildImageContainer(
                                    AppLocalizations.of(context)!.entertainment,
                                    'https://i.pinimg.com/736x/c1/f6/52/c1f6526d8499d10a45e27cee47281996.jpg',
                                    context,
                                    NewsCategory.entertainment,
                                  ),
                                  _buildImageContainer(
                                    AppLocalizations.of(context)!.health,
                                    'https://i.pinimg.com/736x/3d/42/04/3d42045f076135a461c62e1949a35099.jpg',
                                    context,
                                    NewsCategory.health,
                                  ),
                                  _buildImageContainer(
                                    AppLocalizations.of(context)!.business,
                                    'https://i.pinimg.com/736x/1c/4e/89/1c4e8918b36ea9a6e54eab713f630689.jpg',
                                    context,
                                    NewsCategory.business,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuButton(
    String text,
    IconData icon,
    BuildContext context,
    NewsCategory? category,
    Color themeColor,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: InkWell(
        onTap: () {
          if (category != null) {
            Log.i('SIDE_PAGE: Menu tapped: $text - Navigating to Home with category: $category');
            context.goNamed(
              'home',
              pathParameters: {'category': category.index.toString()},
            );
          } else if (text == AppLocalizations.of(context)!.bookmarks) {
            Log.i('SIDE_PAGE: Navigating to Bookmarks');
            context.push('/sidepage/bookmark');
          } else if (text == AppLocalizations.of(context)!.settings) {
            Log.i('SIDE_PAGE: Navigating to Settings');
            context.push('/sidepage/settings');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 45, color: themeColor),
            const SizedBox(height: 8),
            Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsItem(BuildContext context, Article? article) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                article == null
                    ? Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.brightness == Brightness.light
                                ? Colors.black54
                                : Colors.white70,
                          ),
                        ),
                      ),
                    )
                    : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: article.urlToImage,
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) => Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.brightness == Brightness.light
                                        ? Colors.black54
                                        : Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                        errorWidget:
                            (context, url, error) => Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.image_not_supported,
                                color: theme.colorScheme.onSurface.withAlpha(
                                  (0.5 * 255).toInt(),
                                ),
                                size: 30,
                              ),
                            ),
                      ),
                    ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article?.title ?? 'Loading News!!',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  article?.description ??
                      'News description text will come here...',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(
                      (0.7 * 255).toInt(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContainer(
    String text,
    String imageUrl,
    BuildContext context,
    NewsCategory category,
  ) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        Log.i('SIDE_PAGE: Topic tapped: $text - Navigating to Home with category: $category');
        context.goNamed(
          'home',
          pathParameters: {'category': category.index.toString()},
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withAlpha((0.4 * 255).toInt()),
              BlendMode.darken,
            ),
          ),
        ),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              shadows: const [
                Shadow(
                  blurRadius: 10,
                  color: Colors.black54,
                  offset: Offset(2, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

