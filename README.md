# SwiftBlock
This is a Safari content blocker for macOS Catalina and later, where Safari no longer supports the normal uBlock Origin extension. This content blocker aims to replicate the essential parts of uBlock Origin in Apple’s custom content blocker format. It’s currently very rudimentary and allows for no customization*.

To use this content blocker:

- Clone this repository
- Open the Xcode project and run it
- Enable the content blocker in Safari

*you can, however, edit the blocklist files in `~/Library/Group Containers/[some code].net.cloudwithlightning.swiftblock/resources`.

## Troubleshooting
If the content blocker does not appear to be blocking content as it should, it’s likely that a uBlock blocklist contains new unknown syntax and that Safari doesn’t like it. To verify this, check if there is a message `Content Rule List compiling failed: Compiling failed.` in Console.app upon enabling the content blocker in the Safari extension preferences.

Because the error message is accompanied by no debug info, I usually deal with this using the following (terribly inefficient) method:

- opening the content blocker resources folder
- opening all enabled blocklists in TextEdit
- deleting their contents one by one and regenerating and re-enabling until the error does not appear anymore
- then, once the culprit blocklist is found, recursively deleting half of the content and thus finding the erroneous line via binary search
- then, finally, making the code deal with it

