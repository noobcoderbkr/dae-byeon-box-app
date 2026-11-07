"""Guard the lifecycle required by the pinned pre-UIScene messaging plugin."""

import plistlib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class IosConfigTest(unittest.TestCase):
    def test_pinned_messaging_plugin_uses_application_lifecycle(self):
        with (ROOT / "ios/Runner/Info.plist").open("rb") as source:
            config = plistlib.load(source)
        self.assertNotIn("UIApplicationSceneManifest", config)
        self.assertIn("_UIApplicationSceneManifest", config)

    def test_plugins_register_before_application_launch_finishes(self):
        source = (ROOT / "ios/Runner/AppDelegate.swift").read_text()
        self.assertNotIn("FlutterImplicitEngineDelegate", source)
        registration = source.index("GeneratedPluginRegistrant.register(with: self)")
        completion = source.index("return super.application(")
        self.assertLess(registration, completion)


if __name__ == "__main__":
    unittest.main()
