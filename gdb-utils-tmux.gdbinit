python

import sys
import os
import subprocess
import re
from time import sleep
from tempfile import NamedTemporaryFile as mktmp


class cursor:
    left = '\033[1D'
    reset = '\033[K\033[1K\033[B\r\033[A\033[K\033[1K'


def output_():
    def panes(session):
        p = subprocess.Popen(["tmux", "list-panes", "-t", session], stdout=subprocess.PIPE)
        res = p.stdout.read().decode("utf8")
        #print(f"res: {res}")
        active = -1
        panes_ = []
        for s in res.rstrip('\n').split('\n'):
            x = re.findall("%[0-9]+", s)[0]
            panes_.append(x)
            if len(re.findall("\(active\)$", s)) > 0:
                active = x
        #print(f"panes: {panes_}, active: {active}")
        return [active, panes_]

    tmux_env = os.getenv("TMUX")
    if tmux_env:
        session = tmux_env.split(",")[-1]
        pane_id = ""
        [active, panes_] = panes(session)
        while True:
            sys.stdout.write(
                f"[user] configure output pane, " +
                "(s)elect or (c)ancel?  ")
            sys.stdout.write(cursor.left)
            sys.stdout.flush()
            res = sys.stdin.read(1).lower()
            if res == "c":
                return
            elif res == "s":
                subprocess.Popen(["tmux", "display-panes"])
                while True:
                    sys.stdout.write("[user] enter pane # [#/c]:  ")
                    sys.stdout.write(cursor.left)
                    sys.stdout.flush()
                    res2 = sys.stdin.read(1).lower()
                    if res2 == 'c':
                        break
                    elif len(re.findall("^%?[0-9]+$", res2)) > 0:
                        pane_id = re.findall("^%?[0-9]+$", res2)[0]
                        break

                    # reset
                    sys.stdout.write(cursor.reset)

                break

            # reset
            sys.stdout.write(cursor.reset)

        if not pane_id:
            print("[error] no valid pane id set for dashboard output")
            return
        res = ""
        f = mktmp(delete=False)
        fn = f.name
        f.close()
        # get tty
        subprocess.call(["tmux", "send-keys", "-t", f"{session}.{pane_id}", f"stty -echo && tty 1>{fn} && reset", "ENTER"])
        sleep(1)  # wait for terminal to complete its work
        f = open(fn, "r")
        res = f.read()
        f.close()
        os.remove(fn)
        tty = res.rstrip("\n")
        if os.path.exists(tty):
            print(f"pushing dashboard output to '{tty}'")
            gdb.execute(f"dashboard -output {tty}")
        else:
            print(f"no valid tty set")

end
