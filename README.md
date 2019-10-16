# gdb-utils-tmux

## description
python wrapper for restoration of existing gdb 'targets' to tmux panes

**supporting**  
- gdb logging  
- [gdb-dashboard](https://github.com/cyrus-and/gdb-dashboarddashboard) debugging windows

## usage
the functionality can be directly loaded within gdb via `source gdb-utils-tmux.gdbinit` or added to an existing `.gdbinit` rc file

in an attempt to encourage a modular approach to third-party gdb functionality, a 'fragment' directory, e.g. `~/.gdbinit.d` could be set up and managed as follows:

- place all third-party `.gdbinit` fragments (e.g. `gdb-utils-tmux.gdbinit`, `gdb-dashboard.gdbinit` etc. in the fragments directory
- add the `load_inits` functionality (and a call to it!) from the sample `.gdbinit` below to your master `~/.gdbinit`. this is a very basic mechanism for loading multiple init fragments which should be appropriately modified or renamed if a specific load order is required. note the following [diff](#gdb-dashboard-diff) should be applied to *gdb-dashboard* project to ensure the generic set of files in the fragments directory are not loaded multiple times

#### mode switch
```
gdb_utils_tmux_.mode = "auto"
```
- `manual` / `auto` values toggles whether or not a previously set-up pseudo terminal is automatically re-used on load

#### supported 'utils'
```
gdb_utils_tmux_.logging_tail("/tmp/gdb.trace")
```
- prompt to set up a tmux pane for logging

```
gdb_utils_tmux_.dashboard_output()
```
- prompt to set up a tmux pane for dashboard output

#### gdb commands
```
> utils_tmux
dashboard_output  logging_tail
```
- command mode use of the util functions prompts for pane selection regardless of which mode is currently active

### sample .gdbinit
```python
#set debug auto-load
set auto-load gdb-scripts on
set auto-load python-scripts on
add-auto-load-scripts-directory ~/.gdbinit.d/
add-auto-load-safe-path ~/.gdbinit.d/

python
import os

def load_inits():
    inits = []
    for root, dirs, files in os.walk(
              os.path.expanduser("~/.gdbinit.d/"),
              followlinks=True):
        inits += [os.path.join(root, f)
                  for f in files if f.endswith("gdbinit")]
    if len(inits) > 0:
        inits.sort()
        print("\n[info] loading init fragments:")
        for f in inits:
            print(f)
            # store reference for context whilst sourcing
            gdb.__exec_file__=f
            # source code line by line
            gdb.execute("source " + f)

# onload
load_inits()
end

# setup

## gdb logging
set logging file /tmp/gdb.trace
set logging on

## gdb dashboard
dashboard stack -style arguments True
dashboard stack -style locals True
dashboard -layout stack expressions

## gdb-utils-tmux
python
gdb_utils_tmux_ = gdb_utils_tmux()
if gdb_utils_tmux_.is_session():
    print("")
    gdb_utils_tmux_.mode = "auto"
    gdb_utils_tmux_.logging_tail("/tmp/gdb.trace")
    gdb_utils_tmux_.dashboard_output()
    print("")
end
```

## gdb-dashboard diff
```diff
diff --git a/.gdbinit b/.gdbinit
--- a/.gdbinit
+++ b/.gdbinit
@@ -499,7 +499,7 @@ class Dashboard(gdb.Command):

     @staticmethod
     def parse_inits(python):
-        for root, dirs, files in os.walk(os.path.expanduser('~/.gdbinit.d/')):
+        for root, dirs, files in os.walk(os.path.expanduser('~/.gdbinit.d/gdb-dashboard/')):
             dirs.sort()
             for init in sorted(files):
                 path = os.path.join(root, init)

```
