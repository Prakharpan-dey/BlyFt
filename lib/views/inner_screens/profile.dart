import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:blyft/controller/cubit/theme/theme_cubit.dart';
import 'package:blyft/controller/cubit/user_profile/user_profile_cubit.dart';
import 'package:blyft/controller/cubit/user_profile/user_profile_state.dart';
import 'package:blyft/views/common_widgets/common_appbar.dart';
import 'package:blyft/models/theme_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:blyft/l10n/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _particleAnimationController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  bool _isNameEditing = false;
  String _originalName = '';

  @override
  void initState() {
    super.initState();

    _particleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    context.read<UserProfileCubit>().loadUserProfile();
  }

  @override
  void dispose() {
    _particleAnimationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    final userProfileCubit = context.read<UserProfileCubit>();

    // Create a map of only changed fields
    Map<String, dynamic> changedFields = {};

    // Check if name has changed
    if (_nameController.text.trim() != _originalName) {
      changedFields['displayName'] = _nameController.text.trim();
    }

    // Check if image has changed
    if (_selectedImage != null) {
      changedFields['profileImage'] = _selectedImage;
    }

    // Only proceed if there are changes
    if (changedFields.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.noChangesToSave)));
      return;
    }

    // Use the existing updateProfilePartial method which already handles this correctly
    userProfileCubit
        .updateProfilePartial(changedFields)
        .then((_) {
          if (!mounted) return;

          // Update original values after successful save
          setState(() {
            _originalName = _nameController.text.trim();
            _selectedImage = null; // Reset selected image after save
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.profileUpdatedSuccessfully)),
          );
        })
        .catchError((error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppLocalizations.of(context)!.error} updating profile: $error')),
          );
        });
  }

  // UPDATED HELPER METHOD FOR CROPPING
  Future<File?> _cropImage(File imageFile) async {
    final theme = Theme.of(context);
    final currentTheme = context.read<ThemeCubit>().currentTheme;

    // Save the original status bar style
    final originalSystemUiOverlayStyle = SystemChrome.latestStyle;

    try {
      // Set the status bar style for the cropper
      // This makes the status bar opaque and sets its color.
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor:
              currentTheme.primaryColor, // Matches the toolbar color
          statusBarIconBrightness:
              Brightness.light, // For light text/icons on a dark background
          statusBarBrightness: Brightness.dark, // For iOS
        ),
      );

      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: AppLocalizations.of(context)!.editProfile,
            toolbarColor: currentTheme.primaryColor,
            toolbarWidgetColor: theme.colorScheme.onPrimary,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: AppLocalizations.of(context)!.editProfile,
            aspectRatioLockEnabled: true,
            aspectRatioPickerButtonHidden: true,
            resetAspectRatioEnabled: false,
            cropStyle: CropStyle.circle,
          ),
        ],
      );

      if (croppedFile != null) {
        return File(croppedFile.path);
      }
      return null;
    } finally {
      // IMPORTANT: Restore the original status bar style when the cropper is closed
      if (originalSystemUiOverlayStyle != null) {
        SystemChrome.setSystemUIOverlayStyle(originalSystemUiOverlayStyle);
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        // New step: Crop the image
        final croppedImage = await _cropImage(File(image.path));
        if (!mounted) return;

        // Only update state if cropping was successful (not cancelled)
        if (croppedImage != null) {
          setState(() {
            _selectedImage = croppedImage;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context)!.failedToPickImage}: $e')));
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        // New step: Crop the image
        final croppedImage = await _cropImage(File(image.path));
        if (!mounted) return;

        // Only update state if cropping was successful (not cancelled)
        if (croppedImage != null) {
          setState(() {
            _selectedImage = croppedImage;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context)!.failedToTakePhoto}: $e')));
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return BlocBuilder<UserProfileCubit, UserProfileState>(
          builder: (context, state) {
            final user = state.user;
            return SafeArea(
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: Text(AppLocalizations.of(context)!.takePhoto),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromCamera();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: Text(AppLocalizations.of(context)!.chooseFromGallery),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromGallery();
                    },
                  ),
                  if (_selectedImage != null || _hasProfileImage(state, user))
                    ListTile(
                      leading: const Icon(Icons.delete),
                      title: Text(AppLocalizations.of(context)!.removePhoto),
                      onTap: () {
                        Navigator.pop(context);
                        _removeProfilePhoto(); // Use the new method
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _removeProfilePhoto() async {
    // Immediately clear the selected image for instant UI update
    setState(() {
      _selectedImage = null;
    });

    try {
      final userProfileCubit = context.read<UserProfileCubit>();
      await userProfileCubit.removeProfileImage();

        if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.profilePhotoRemovedSuccessfully)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context)!.errorRemovingPhoto}: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = context.watch<ThemeCubit>().currentTheme;
    final theme = Theme.of(context);

    return BlocConsumer<UserProfileCubit, UserProfileState>(
      listener: (context, state) {
        if (state.status == UserProfileStatus.loaded && state.user != null) {
          // Only update controllers if they're empty or different
          if (_nameController.text != state.user!.displayName) {
            _nameController.text = state.user!.displayName;
          }
          if (_emailController.text != state.user!.email) {
            _emailController.text = state.user!.email;
          }
          _originalName = state.user!.displayName;
        }
      },
      builder: (context, state) {
        if (state.status == UserProfileStatus.error) {
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: Center(child: Text('${AppLocalizations.of(context)!.error}: ${state.errorMessage}')),
          );
        }

        final user = state.user;
        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: theme.colorScheme.surface.withAlpha(
                  (0.85 * 255).toInt(),
                ),
                expandedHeight: 90,
                pinned: true,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: ParticlesHeader(
                    title: AppLocalizations.of(context)!.profileSettings,
                    themeColor: currentTheme.primaryColor,
                    particleAnimation: _particleAnimationController,
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  color: theme.colorScheme.onSurface.withAlpha(
                    (0.7 * 255).toInt(),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            GestureDetector(
                              onTap: _showImageOptions,
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  state.status == UserProfileStatus.loading
                                      ? CircleAvatar(
                                        radius: 50,
                                        backgroundColor: currentTheme
                                            .primaryColor
                                            .withAlpha((0.2 * 255).toInt()),
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  theme.brightness ==
                                                          Brightness.light
                                                      ? Colors.black54
                                                      : Colors.white70,
                                                ),
                                          ),
                                        ),
                                      )
                                      : CircleAvatar(
                                        radius: 50,
                                        backgroundColor:
                                            _hasProfileImage(state, user)
                                                ? Colors.transparent
                                                : currentTheme.primaryColor
                                                    .withAlpha(
                                                      (0.2 * 255).toInt(),
                                                    ),
                                        backgroundImage: _getProfileImage(
                                          state,
                                          user,
                                        ),
                                        child:
                                            !_hasProfileImage(state, user)
                                                ? Text(
                                                  user
                                                              ?.displayName
                                                              .isNotEmpty ==
                                                          true
                                                      ? user!.displayName[0]
                                                          .toUpperCase()
                                                      : '?',
                                                  style: TextStyle(
                                                    fontSize: 40,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        currentTheme
                                                            .primaryColor,
                                                  ),
                                                )
                                                : null,
                                      ),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: currentTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: theme.colorScheme.surface,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.edit,
                                      size: 20,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        _buildProfileFieldCard(
                          icon: Icons.person,
                          title: AppLocalizations.of(context)!.fullName,
                          controller: _nameController,
                          currentTheme: currentTheme,
                          enabled: _isNameEditing,
                          onEditTap: () {
                            setState(() {
                              _isNameEditing = !_isNameEditing;
                            });
                          },
                        ),
                        _buildProfileFieldCard(
                          icon: Icons.email,
                          title: AppLocalizations.of(context)!.emailAddress,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          enabled: false,
                          currentTheme: currentTheme,
                        ),
                        _buildProfileOption(
                          icon: Icons.verified_user,
                          title: AppLocalizations.of(context)!.emailVerified,
                          subtitle: user?.emailVerified == true ? AppLocalizations.of(context)!.yes : AppLocalizations.of(context)!.no,
                          onTap: () {},
                          currentTheme: currentTheme,
                        ),
                        _buildProfileOption(
                          icon: Icons.calendar_today,
                          title: AppLocalizations.of(context)!.accountCreated,
                          subtitle:
                              user?.createdAt != null
                                  ? '${user!.createdAt!.day}/${user.createdAt!.month}/${user.createdAt!.year}'
                                  : AppLocalizations.of(context)!.unknown,
                          onTap: () {},
                          currentTheme: currentTheme,
                        ),
                        _buildProfileOption(
                          icon: Icons.update,
                          title: AppLocalizations.of(context)!.lastUpdated,
                          subtitle:
                              user?.updatedAt != null
                                  ? '${user!.updatedAt!.day}/${user.updatedAt!.month}/${user.updatedAt!.year}'
                                  : AppLocalizations.of(context)!.never,
                          onTap: () {},
                          currentTheme: currentTheme,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _hasChanges() ? _saveProfile : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _hasChanges()
                                    ? currentTheme.primaryColor
                                    : theme.colorScheme.onSurface.withAlpha(
                                      (0.12 * 255).toInt(),
                                    ),
                            foregroundColor:
                                _hasChanges()
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface.withAlpha(
                                      (0.38 * 255).toInt(),
                                    ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.saveChanges,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _hasChanges() {
    // Check if name has changed
    bool nameChanged = _nameController.text.trim() != _originalName;

    // Check if image has changed (new image selected or existing image removed)
    bool imageChanged = _selectedImage != null;

    return nameChanged || imageChanged;
  }

  bool _hasProfileImage(UserProfileState state, user) {
    return _selectedImage != null ||
        state.localProfileImage != null ||
        (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty);
  }

  ImageProvider? _getProfileImage(UserProfileState state, user) {
    // Priority: selected image -> local image -> network image
    if (_selectedImage != null) {
      return FileImage(_selectedImage!);
    }
    if (state.localProfileImage != null) {
      return FileImage(state.localProfileImage!);
    }
    if (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty) {
      return NetworkImage(user.profileImageUrl!);
    }
    return null;
  }

  Widget _buildProfileFieldCard({
    required IconData icon,
    required String title,
    required TextEditingController controller,
    required AppTheme currentTheme,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    VoidCallback? onEditTap,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withAlpha((0.08 * 255).toInt()),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: currentTheme.primaryColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  enabled
                      ? TextFormField(
                        controller: controller,
                        keyboardType: keyboardType,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          border:
                              enabled
                                  ? UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: currentTheme.primaryColor
                                          .withAlpha((0.3 * 255).toInt()),
                                    ),
                                  )
                                  : InputBorder.none,
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: currentTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 4,
                          ),
                          isDense: true,
                        ),
                      )
                      : Text(
                        controller.text.isEmpty
                            ? AppLocalizations.of(context)!.loading
                            : controller.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(
                            (0.7 * 255).toInt(),
                          ),
                        ),
                      ),
                ],
              ),
            ),
            if (onEditTap != null)
              GestureDetector(
                onTap: () {
                  if (enabled) {
                    if (controller.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context)!.nameCannotBeBlank)),
                      );
                      return;
                    }
                  }
                  onEditTap.call();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        enabled
                            ? currentTheme.primaryColor.withAlpha(
                              (0.1 * 255).toInt(),
                            )
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    enabled ? Icons.check : Icons.edit_outlined,
                    size: 18,
                    color:
                        enabled
                            ? currentTheme.primaryColor
                            : currentTheme.primaryColor.withAlpha(
                              (0.7 * 255).toInt(),
                            ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required AppTheme currentTheme,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withAlpha((0.08 * 255).toInt()),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: currentTheme.primaryColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
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
      ),
    );
  }
}

