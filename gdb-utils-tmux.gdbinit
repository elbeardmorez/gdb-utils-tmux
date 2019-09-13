python

import sys
import os
import subprocess
import re
from time import sleep
from tempfile import NamedTemporaryFile as mktmp, gettempdir as tmpdir


class state(dict):

    def __init__(self):
        super()
        self["tty_dashboard"] = ""
        self["tty_logging"] = ""


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
        attempt = 0
        while attempt < 5:
            try:
                if sys.version_info > (2, 7):
                    return input()  # python 3
                else:
                    return raw_input()  # python 2
                break
            except Exception:
                sleep(0.1)
        attempt += 1


class gdb_tmux:

    class pane:
        desc = ""
        id = ""
        tty = ""
        active = False

    @staticmethod
    def session():
        tmux_env = os.getenv("TMUX")
        if tmux_env:
            return [0, int(tmux_env.split(",")[-1])]
        else:
            return [1, -1]

    @staticmethod
    def panes(session_):
        format_ = '#{pane_index}|#{pane_id}|#{pane_tty}|' + \
                  '#{pane_width}x#{pane_height}|' + \
                  '#{history_size}/#{history_limit}|#{pane_active}'
        IDX_ID = 1
        IDX_TTY = 2
        IDX_ACTIVE = 5
        p = subprocess.Popen(["tmux", "list-panes", "-t", str(session_),
                              "-F", format_], stdout=subprocess.PIPE)
        res = p.stdout.read().decode("utf8")
        panes_ = []
        for s in res.rstrip('\n').split('\n'):
            parts = s.split('|')
            p = gdb_tmux.pane()
            panes_.append(p)
            p.desc = s
            p.id = parts[IDX_ID]
            p.tty = parts[IDX_TTY]
            if parts[IDX_ACTIVE] == '1':
                p.active = True

        return panes_

    @staticmethod
    def select_pane(session_, msg="select pane #"):
        err = 0
        pane_ = None

        panes_ = gdb_tmux.panes(session_)
        if len(panes_) == 1:
            return [err, panes_[0]]
        subprocess.Popen(["tmux", "display-panes", ""])
        panes_range = "0" if len(panes_) == 1 else "0-" + str(len(panes_) - 1)
        utils.reset_line()
        while True:
            sys.stdout.write(f"[user] {msg} or (c)ancel [{panes_range}|c]:  ")
            sys.stdout.write(utils.cursor.left)
            sys.stdout.flush()
            res = utils.input_().lower()
            if res == "c":
                break
            elif len(re.findall("^[0-9]+$", res)) > 0:
                pane_idx = re.findall("^[0-9]+$", res)[0]
                if int(pane_idx) < len(panes_):
                    pane_ = panes_[int(pane_idx)]
                    break

            # reset
            utils.reset_line()

        return [err, pane_]

    @staticmethod
    def add_pane(session_):
        err = 0
        pane_ = None

        [err_, pane_] = gdb_tmux.select_pane(
                            session_, "set base pane # for split")
        if err_ or not pane_:
            return [err_, pane_]

        panes_ = gdb_tmux.panes(session_)
        subprocess.call(["tmux", "split-window", "-t",
                        f"{session_}.{pane_.id}", "-h"])
        # reselect original active pane
        active = next(p for p in panes_ if p.active)
        subprocess.call(["tmux", "select-pane", "-t",
                        f"{session_}.{active.id }"])
        panes_2 = gdb_tmux.panes(session_)
        added = [p for p in panes_2 if p.id not in [p.id for p in panes_]]
        if len(added) != 1:
            print(f"[error] detected {len(added)} panes, " +
                  "failed to get new pane id")
        else:
            pane_ = added[0]

        return [err, pane_]

    @staticmethod
    def set_pane(session_, msg="configure output pane"):
        err = 0
        pane_ = None
        while True:
            sys.stdout.write(
                "[user]" + (f" {msg}," if msg else "") +
                " (s)elect, (a)dd, or (c)ancel? [s|a|c]:  ")
            sys.stdout.write(utils.cursor.left)
            sys.stdout.flush()
            res = sys.stdin.read(1).lower()
            if res == "c":
                sys.stdout.write('\n')
                sys.stdout.flush()
                break
            elif res == "s":
                [err, pane_] = gdb_tmux.select_pane(session_)
                if err:
                    break
                elif pane_:
                    break
            elif res == "a":
                [err, pane_] = gdb_tmux.add_pane(session_)
                if err:
                    break
                elif pane_:
                    break

            if pane_:
                break
            # reset
            utils.reset_line()

        return [err, pane_]


class gdb_utils_tmux(gdb.Command):

    trace_file = "gdb.trace"
    state_file = "gdb_utils_tmux.state"

    state = None

    class gdb_command_utils_tmux_dashboard_output(gdb.Command):
        def __init__(self, gdb_utils_tmux_):
            self.gdb_utils_tmux = gdb_utils_tmux_
            gdb.Command.__init__(
                self, 'utils_tmux dashboard_output', gdb.COMMAND_USER)

        def invoke(self, arg, from_tty):
            self.gdb_utils_tmux.dashboard_output()

    class gdb_command_utils_tmux_logging_tail(gdb.Command):
        def __init__(self, gdb_utils_tmux_):
            self.gdb_utils_tmux = gdb_utils_tmux_
            gdb.Command.__init__(
                self, 'utils_tmux logging_tail', gdb.COMMAND_USER)

        def invoke(self, arg, from_tty):
            self.gdb_utils_tmux.logging_tail()

    def __init__(self):
        gdb.Command.__init__(
            self, 'utils_tmux', gdb.COMMAND_USER, gdb.COMPLETE_NONE, True)
        gdb_utils_tmux.gdb_command_utils_tmux_dashboard_output(self)
        gdb_utils_tmux.gdb_command_utils_tmux_logging_tail(self)
        self.state_load()

    def is_session(self):
        [err, session_] = gdb_tmux.session()
        return False if err else True

    def dashboard_output(self):
        [err, session_] = gdb_tmux.session()
        if err:
            print("[error] non-tmux session")
            return

        tty = self.state["tty_dashboard"]
        pane_ = None
        if os.path.exists(tty):
            panes_ = [p for p in gdb_tmux.panes(session_) if p.tty == tty]
            if len(panes_) == 1:
                pane_ = panes_[0]

        if not pane_:
            self.state_set("tty_dashboard", "")
            [err, pane_] = gdb_tmux.set_pane(
                               session_,
                               "configure dashboard output pane")
            if err or not pane_:
                if err:
                    print("[error] no valid pane id set for dashboard output")
                return
            tty = pane_.tty
            self.state_set("tty_dashboard", tty)

        # configure dashboard
        print(f"pushing dashboard output to '{tty}'")
        gdb.execute(f"dashboard -output {tty}")

    def logging_tail(self, target=""):
        [err, session_] = gdb_tmux.session()
        if err:
            print("[error] non-tmux session")
            return

        if not target:
            target = os.path.join(tmpdir(), self.trace_file)

        tty = self.state["tty_logging"]
        pane_ = None
        if os.path.exists(tty):
            panes_ = [p for p in gdb_tmux.panes(session_) if p.tty == tty]
            if len(panes_) == 1:
                pane_ = panes_[0]

        if not pane_:
            self.state_set("tty_logging", "")
            [err, pane_] = gdb_tmux.set_pane(
                               session_,
                               "configure terminal logging-tail pane")
            if err or not pane_:
                if err:
                    print("[error] no valid pane id set for logging tail")
                return
            tty = pane_.tty
            self.state_set("tty_logging", tty)

        # configure logging tail
        print(f"tailing logs on '{tty}'")
        subprocess.call(["tmux", "send-keys", "-t",
                         f"{session_}.{pane_.id}", "C-c"])
        subprocess.call(["tmux", "send-keys", "-t",
                         f"{session_}.{pane_.id}",
                         f"tail -f {target}", "ENTER"])
        gdb.execute(f"set logging file {target}")

        # logging state
        if gdb.execute("show logging redirect",
                       to_string=True).find("Currently logging") > -1:
            gdb.execute("set logging on")

    def state_load(self):
        if not self.state:
            # rebuild
            self.state_rebuild()
        for k in ["tty_dashboard", "tty_logging"]:
            if not os.path.exists(self.state[k]):
                self.state[k] = ""

    def state_rebuild(self):
        self.state = state()
        target = os.path.join(tmpdir(), self.state_file)
        if not os.path.exists(target):
            return

        f = open(target, "r")
        data = [line.rstrip('\n') for line in f.readlines()]
        f.close()
        for [k, v] in [r.split('|') for r in data]:
            self.state[k] = v

    def state_set(self, key, value):
        self.state[key] = value
        self.state_persist()

    def state_persist(self):
        if not self.state:
            print("[info] no state object set")
            return
        data = '\n'.join([f"{k}|{v}" for k, v in self.state.items()])
        target = os.path.join(tmpdir(), self.state_file)
        f = open(target, "w")
        f.write(data)
        f.close()

end
