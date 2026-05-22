# Widget Extension Setup

To add the widget to the Xcode project:

1. **Add new target**: File > New > Target > Widget Extension
   - Name: LifeOSWidget
   - Uncheck "Include Configuration App Intent"

2. **Add App Group capability** (both targets):
   - Main app target > Signing & Capabilities > + > App Groups
   - Check: `group.com.lifeos.app`
   - Widget target > same steps

3. **Replace generated files** with the Swift files in this directory.

4. **Add these files to both targets**:
   - Models needed by widget (if reading from SwiftData)
   - For App Group shared UserDefaults, no model sharing needed

5. **Build scheme**: Ensure widget target is included in the build.
