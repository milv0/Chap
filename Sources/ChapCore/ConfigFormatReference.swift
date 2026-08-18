import Foundation

/// Self-contained JSON format reference for import guidance.
/// Shown when an import is blocked so users can correct their file
/// without consulting an external URL.
enum ConfigFormatReference {
    /// Minimal valid JSON config example covering all four launch types.
    static let exampleJSON = """
        {
          "sites": [
            {
              "name": "GitHub",
              "url": "https://github.com/",
              "width": 800,
              "height": 600,
              "launchType": "url"
            },
            {
              "name": "Slack",
              "url": "",
              "launchType": "app",
              "appPath": "/Applications/Slack.app",
              "width": 1200,
              "height": 800
            },
            {
              "name": "Downloads",
              "url": "",
              "launchType": "finder",
              "folderPath": "~/Downloads",
              "width": 1000,
              "height": 400
            },
            {
              "name": "Build",
              "url": "",
              "launchType": "shell",
              "script": "echo hello",
              "width": 800,
              "height": 600
            }
          ]
        }
        """

    /// Field requirements per launch type, for display in alerts.
    static let fieldRequirements = """
        Required fields per launch type:
        • url:    name, url (https://…), width, height
        • app:    name, appPath, width, height
        • finder: name, folderPath, width, height
        • shell:  name, script, width, height

        Optional: shortcut, displayName, windowSizePreset
        """
}
