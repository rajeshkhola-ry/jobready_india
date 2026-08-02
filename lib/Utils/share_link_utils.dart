class ShareLinkUtils {
  static bool isValidShareableUrl(String? value) {
    if (value == null || value.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) {
      return false;
    }

    return uri.scheme == 'https' || uri.scheme == 'blob';
  }
}
