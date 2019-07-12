python

import sys
import os
import subprocess
import re
from time import sleep
from tempfile import NamedTemporaryFile as mktmp, gettempdir as tmpdir

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


class gdb_tmux:

    @staticmethod
    def session():
        tmux_env = os.getenv("TMUX")
        if not tmux_env:
            print("non-tmux session")
            return -1
        return int(tmux_env.split(",")[-1])

    @staticmethod
    def panes(session_):
        p = subprocess.Popen(["tmux", "list-panes", "-t", str(session_)], stdout=subprocess.PIPE)
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

    @staticmethod
    def select_pane(session_, msg="select pane"):
        pane_id = ""

        [active, panes_] = gdb_tmux.panes(session_)
        subprocess.Popen(["tmux", "display-panes"])
        while True:
            sys.stdout.write(
                "[user]" + (f" {msg}, " if msg else "") +
                f" (0-{len(panes_) - 1}) / (c)ancel [#/c]:  ")
            sys.stdout.write(utils.cursor.left)
            sys.stdout.flush()
            res = utils.input_().lower()
            if res == "c":
                break
            elif len(re.findall("^[0-9]+$", res)) > 0:
                pane_ = re.findall("^[0-9]+$", res)[0]
                if int(pane_) < len(panes_):
                    pane_id = re.findall("%[0-9]+", panes_[int(pane_)])[0]
                    #print(f"pane_id: {pane_id}")
                    break

            # reset
            utils.reset_line()

        return pane_id

    @staticmethod
    def add_pane(session_):
        pane_id = ""

        pane_id_ = gdb_tmux.select_pane(session_, "set base pane for split")
        if not pane_id_:
            return pane_id

        [active, panes_] = gdb_tmux.panes(session_)
        subprocess.call(["tmux", "select-pane", "-t", f"{session_}.{pane_id_}"])
        subprocess.call(["tmux", "split-window", "-t", str(session_), "-h"])
        subprocess.call(["tmux", "select-pane", "-t", f"{session_}.{active}"])
        [_, panes_2] = gdb_tmux.panes(session_)
        added = [p for p in panes_2 if p not in panes_]
        if len(added) != 1:
            print(f"[error] detected {len(added)} panes, failed to get new pane id")
        else:
            pane_id = added[0]

        return pane_id

    @staticmethod
    def set_pane(session_, msg="configure output pane"):
        pane_id = ""
        [_, panes_] = gdb_tmux.panes(session_)
        while True:
            sys.stdout.write(
                "[user]" + (f" {msg}, " if msg else "") +
                "(s)elect, (a)dd, or (c)ancel? [s/a/c]:  ")
            sys.stdout.write(utils.cursor.left)
            sys.stdout.flush()
            res = sys.stdin.read(1).lower()
            if res == "c":
                return
            elif res == "s":
                pane_id = gdb_tmux.select_pane(session_)
            elif res == "a":
                pane_id = gdb_tmux.add_pane(session_)

            if pane_id:
                break
            # reset
            utils.reset_line()

        return pane_id


class gdb_utils_tmux:

    def dashboard_output(self):
        session_ = gdb_tmux.session()
        if not session_:
            print("non-tmux session")
            return

        pane_id = gdb_tmux.set_pane(session_, "configure dashboard output pane")
        if not pane_id:
            print("[error] no valid pane id set for dashboard output")
            return

        res = ""
        f = mktmp(delete=False)
        fn = f.name
        f.close()
        # get tty
        subprocess.call(["tmux", "send-keys", "-t", f"{session_}.{pane_id}", f"stty -echo && tty 1>{fn} && reset", "ENTER"])
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

    def logging_tail(self, target=""):
        session_ = gdb_tmux.session()
        if not session_:
            print("non-tmux session")
            return

        if not target:
            target = os.path.join(tmpdir(), "gdb.trace")

        pane_id = gdb_tmux.set_pane(session_, "configure terminal logging-tail pane")
        if not pane_id:
            print("[error] no valid pane id set for logging tail")
            return
        subprocess.call(["tmux", "send-keys", "-t", f"{session_}.{pane_id}", f"tail -f {target}", "ENTER"])
        gdb.execute(f"set logging file {target}")
        gdb.execute("set logging on")

end
