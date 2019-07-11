python

import sys
import os
import subprocess
import re
from time import sleep
from tempfile import NamedTemporaryFile as mktmp

class utils:

    class cursor:
        left = '\033[1D'
        reset = '\033[K\033[1K\033[B\r\033[A\033[K\033[1K'

    @staticmethod
    def reset_line():
        sys.stdout.write(utils.cursor.reset)
        sys.stdout.flush()

    @staticmethod
    def input_():
        try:
            return input()  # python 3
        except:
            return raw_input()  # python 2


class gdb_utils_tmux:

    def panes(self, session):
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

    def output_(self):
        session = os.getenv("TMUX").split(",")[-1]
        if not session:
            print("non-tmux session")
            return -1

        pane_id = ""
        [active, panes_] = self.panes(session)
        while True:
            sys.stdout.write(
                f"[user] configure output pane, " +
                "(s)elect or (c)ancel?  ")
            sys.stdout.write(utils.cursor.left)
            sys.stdout.flush()
            res = sys.stdin.read(1).lower()
            if res == "c":
                return
            elif res == "s":
                subprocess.Popen(["tmux", "display-panes"])
                while True:
                    sys.stdout.write("[user] enter pane # [#/c]:  ")
                    sys.stdout.write(utils.cursor.left)
                    sys.stdout.flush()
                    res2 = utils.input_().lower()
                    if res2 == 'c':
                        break
                    elif len(re.findall("^%?[0-9]+$", res2)) > 0:
                        pane_id = re.findall("^%?[0-9]+$", res2)[0]
                        break

                    # reset
                    utils.reset_line()

            if pane_id:
                break
            # reset
            utils.reset_line()

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
