import 'dart:typed_data';

class StoryState {
  static final StoryState instance = StoryState._();
  StoryState._();
  Uint8List? myStoryBytes;
  String? myStoryUrl;

  void removeStory() {
    myStoryBytes = null;
    myStoryUrl = null;
  }
}
