set root to (POSIX path of (path to home folder)) & "Library/Application Support/CodexSidebarMeter"
do shell script "mkdir -p " & quoted form of (root & "/.runtime")
do shell script "nohup " & quoted form of (root & "/runtime/node") & " " & quoted form of (root & "/mac/launch.mjs") & " > " & quoted form of (root & "/.runtime/mac.log") & " 2>&1 < /dev/null &"
