import os
import re
import shutil
import json
import time

LOG_FILE = '/tmp/nbsail_debug.log'

def log(msg):
    """Skriver meldinger til stdout og loggfil."""
    try:
        safe_msg = str(msg)
        clean_stdout_msg = safe_msg.encode('ascii', errors='backslashreplace').decode('ascii')
        print(f"[NBSAIL] {clean_stdout_msg}")

        with open(LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(f"{safe_msg}\n")
    except Exception:
        pass

def get_default_notes_dir(*args, **kwargs):
    """Returnerer rotmappen for alle notatblokker (~/Documents/notes)."""
    docs_notes = os.path.expanduser("~/Documents/notes")
    if not os.path.exists(docs_notes):
        try:
            os.makedirs(docs_notes, exist_ok=True)
        except Exception:
            pass
    return docs_notes

def init_environment(*args, **kwargs):
    """Initialiserer innstillinger og config.json hvis den ikke finnes."""
    notes_dir = get_default_notes_dir()
    config_dir = os.path.expanduser("~/.config/NBsail")
    config_file = os.path.join(config_dir, "config.json")

    if not os.path.exists(notes_dir):
        os.makedirs(notes_dir, exist_ok=True)

    # ENDRET: Bruker quickNotes i stedet for home som standard
    default_config = {
        "notes_path": os.path.join(notes_dir, "quickNotes"),
        "active_notebook": "quickNotes",
        "language": "en"
    }

    if not os.path.exists(config_dir):
        try:
            os.makedirs(config_dir, exist_ok=True)
        except Exception:
            pass

    if not os.path.exists(config_file):
        try:
            with open(config_file, "w", encoding="utf-8") as f:
                json.dump(default_config, f, indent=4)
        except Exception as e:
            log(f"Feil ved opprettelse av config.json: {e}")
        return default_config

    try:
        with open(config_file, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        log(f"Feil ved lesing av config.json: {e}")
        return default_config

def get_setting(key="active_notebook", default=None, *args, **kwargs):
    """Henter en innstilling fra config.json."""
    config = init_environment()
    return config.get(key, default)

def set_setting(key=None, value=None, *args, **kwargs):
    """Oppdaterer en innstilling i config.json."""
    if not key:
        return "Error: Missing key"
    config_dir = os.path.expanduser("~/.config/NBsail")
    config_file = os.path.join(config_dir, "config.json")
    config = init_environment()
    config[key] = value
    try:
        with open(config_file, "w", encoding="utf-8") as f:
            json.dump(config, f, indent=4)
        return "OK"
    except Exception as e:
        log(f"Feil ved lagring i config.json: {e}")
        return f"Error: {str(e)}"

def save_setting(key=None, value=None, *args, **kwargs):
    return set_setting(key, value, *args, **kwargs)

def get_active_notebook_dir(*args, **kwargs):
    """Henter den absolutte stien til mappen for den aktive notatblokken."""
    active_nb = get_setting("active_notebook", "quickNotes")
    base_dir = get_default_notes_dir()
    nb_path = os.path.join(base_dir, active_nb)
    if not os.path.exists(nb_path):
        os.makedirs(nb_path, exist_ok=True)
    return nb_path

# ==============================================================================
# --- NOTATBLOKK-HÅNDTERING ---
# ==============================================================================

def get_notebooks(*args, **kwargs):
    """Returnerer en sortert liste over alle notatblokker i ~/Documents/notes."""
    try:
        docs_base = get_default_notes_dir()
        notebooks = set()

        if os.path.exists(docs_base):
            for entry in os.listdir(docs_base):
                full_path = os.path.join(docs_base, entry)
                if os.path.isdir(full_path) and not entry.startswith('.'):
                    notebooks.add(entry)

        if not notebooks:
            notebooks.add("quickNotes")

        return sorted(list(notebooks))
    except Exception as e:
        log(f"Feil ved henting av notatblokker: {e}")
        return ["quickNotes"]

def get_active_notebook(*args, **kwargs):
    """Returnerer navnet på aktiv notatblokk."""
    return get_setting("active_notebook", "quickNotes")

def set_active_notebook(notebook_name=None, *args, **kwargs):
    """Bytter aktiv notatblokk og oppdaterer stier."""
    if notebook_name is None and args:
        notebook_name = args[0]

    if not notebook_name:
        return "Error: Ugyldig notatblokknavn"

    clean_name = str(notebook_name).strip()
    target_path = os.path.join(get_default_notes_dir(), clean_name)
    os.makedirs(target_path, exist_ok=True)

    set_setting("notes_path", target_path)
    set_setting("active_notebook", clean_name)
    log(f"Byttet aktiv notatblokk til: {clean_name} ({target_path})")
    return "OK"

def create_notebook(notebook_name=None, *args, **kwargs):
    """Oppretter en ny notatblokk under ~/Documents/notes/ og aktiverer den."""
    if notebook_name is None and args:
        notebook_name = args[0]

    if not notebook_name or not str(notebook_name).strip():
        return "Error: Ugyldig navn"

    return set_active_notebook(notebook_name)

# ==============================================================================
# --- TRESTRUKTUR OG NOTATER ---
# ==============================================================================

def extract_title_from_file(full_path):
    """Henter ut H1-tittel (# Overskrift) fra en Markdown-fil, eller filnavn som fallback."""
    try:
        with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                line_str = line.strip()
                if not line_str:
                    continue
                if line_str.startswith('#'):
                    return line_str.lstrip('#').strip()
                else:
                    words = line_str.split()
                    return " ".join(words[:3])
    except Exception:
        pass
    return os.path.basename(full_path)

def get_tree_structure(*args, **kwargs):
    """Genererer trestrukturen for den aktive notatblokken til QML."""
    try:
        nb_dir = get_active_notebook_dir()
        items = []
        active_nb_name = get_active_notebook()

        # 1. Rot-element (Beholder teknisk ID quickNotes_root for QML-trestrukturen)
        items.append({
            "id": "dir:quickNotes_root",
            "title": str(active_nb_name),
            "is_dir": True,
            "level": 0,
            "parent": ""
        })

        ignored_dirs = {".git", ".basket", "config.json"}

        # 2. Legg til Filer direkte i rotmappen FØRST
        root_files = []
        try:
            for entry in os.listdir(nb_dir):
                full_path = os.path.join(nb_dir, entry)
                if os.path.isfile(full_path) and not entry.startswith('.') and entry not in ignored_dirs:
                    root_files.append((entry, full_path))
        except Exception as e:
            log(f"Feil ved skanning av rotmappe: {e}")

        for filename, full_path in sorted(root_files, key=lambda x: x[0].lower()):
            display_title = extract_title_from_file(full_path)
            items.append({
                "id": str(filename),
                "title": str(display_title),
                "is_dir": False,
                "level": 1,
                "parent": "dir:quickNotes_root"
            })

        # 3. Les alle undermapper og deres filer
        dir_dict = {}
        for root, dirs, files in os.walk(nb_dir):
            dirs[:] = [d for d in dirs if not d.startswith('.') and d.lower() not in ignored_dirs]

            rel_root = os.path.relpath(root, nb_dir)
            if rel_root == ".":
                continue

            valid_files = [f for f in files if not f.startswith('.') and f not in ignored_dirs]
            dir_dict[rel_root] = {
                "root": root,
                "files": sorted(valid_files, key=lambda x: x.lower())
            }

        sorted_dir_keys = sorted(dir_dict.keys(), key=lambda x: x.lower())

        # 4. Legg til mapper og deres filer etter rotfilene
        for rel_dir in sorted_dir_keys:
            dir_info = dir_dict[rel_dir]
            dir_id = f"dir:{rel_dir}"
            parent_dir = os.path.dirname(rel_dir)
            dir_name = os.path.basename(rel_dir)

            level = int(rel_dir.count(os.sep)) + 1

            items.append({
                "id": dir_id,
                "title": str(dir_name),
                "is_dir": True,
                "level": level,
                "parent": str(f"dir:{parent_dir}" if parent_dir and parent_dir != "." else "dir:quickNotes_root")
            })

            for file in dir_info["files"]:
                full_path = os.path.join(dir_info["root"], file)
                rel_file_path = os.path.relpath(full_path, nb_dir)
                display_title = extract_title_from_file(full_path)

                items.append({
                    "id": str(rel_file_path),
                    "title": str(display_title),
                    "is_dir": False,
                    "level": level + 1,
                    "parent": str(dir_id)
                })

        return items
    except Exception as e:
        return [{"id": "err", "title": f"Feil: {str(e)}", "is_dir": False, "level": 0, "parent": ""}]

def get_recent_notes(limit=10, *args, **kwargs):
    """Henter de N sist endrede notatene i den aktive notatblokken."""
    try:
        if args and isinstance(args[0], (int, str)):
            try:
                limit = int(args[0])
            except ValueError:
                pass
        elif "limit" in kwargs:
            try:
                limit = int(kwargs["limit"])
            except ValueError:
                pass
    except Exception:
        limit = 10

    try:
        nb_dir = get_active_notebook_dir()
        files_with_mtime = []

        for root, dirs, files in os.walk(nb_dir):
            dirs[:] = [d for d in dirs if not d.startswith('.') and d not in (".basket", ".git")]

            for file in files:
                if file.startswith('.') or file == "config.json":
                    continue

                full_path = os.path.join(root, file)
                rel_file_path = os.path.relpath(full_path, nb_dir)
                rel_root = os.path.relpath(root, nb_dir)

                try:
                    mtime = os.path.getmtime(full_path)
                except Exception:
                    mtime = 0

                parent_dir = "" if rel_root == "." else rel_root

                files_with_mtime.append({
                    "full_path": full_path,
                    "rel_path": rel_file_path,
                    "parent": parent_dir,
                    "mtime": mtime
                })

        files_with_mtime.sort(key=lambda x: x["mtime"], reverse=True)

        recent_items = []
        for item in files_with_mtime[:limit]:
            display_title = extract_title_from_file(item["full_path"])
            recent_items.append({
                "id": str(item["rel_path"]),
                "title": str(display_title),
                "is_dir": False,
                "level": 0 if not item["parent"] else int(item["parent"].count(os.sep) + 1),
                "parent": str(item["parent"])
            })

        return recent_items
    except Exception as e:
        log(f"Feil i get_recent_notes: {e}")
        return [{"id": "err", "title": f"Feil: {str(e)}", "is_dir": False, "level": 0, "parent": ""}]

def get_bookmarks(limit=10, *args, **kwargs):
    """Wrapper for favoritter på FavoritesPage."""
    return get_recent_notes(limit, *args, **kwargs)

def resolve_note_path(note_id):
    """
    Hjelpefunksjon for å finne absolutt filsti for et notat/element.
    Sjekker i aktiv notebook først, deretter direkte mot ~/Documents/notes.
    """
    if not note_id:
        return None

    clean_path = str(note_id).replace("dir:", "").strip()
    if not clean_path:
        return None

    if os.path.isabs(clean_path) and os.path.exists(clean_path):
        return clean_path

    active_nb_dir = get_active_notebook_dir()
    path_in_active = os.path.join(active_nb_dir, clean_path)
    if os.path.exists(path_in_active):
        return path_in_active

    base_dir = get_default_notes_dir()
    path_in_base = os.path.join(base_dir, clean_path)
    if os.path.exists(path_in_base):
        return path_in_base

    return path_in_active

def get_note_content(note_id=None, *args, **kwargs):
    """Leser og returnerer innholdet i et notat direkte fra disken."""
    try:
        if note_id is None and args:
            note_id = args[0]
        if not note_id:
            return ""

        full_path = resolve_note_path(note_id)

        if full_path and os.path.exists(full_path) and os.path.isfile(full_path):
            with open(full_path, 'r', encoding='utf-8', errors='replace') as f:
                return f.read()

        clean_path = str(note_id).replace("dir:", "").strip()
        return f"Feil: Filen ble ikke funnet ({clean_path})"
    except Exception as e:
        return f"Feil ved åpning av notat: {str(e)}"

def save_note_content(note_id=None, new_content="", *args, **kwargs):
    """Lagrer oppdatert innhold i et eksisterende notat."""
    try:
        if note_id is None and args:
            note_id = args[0]
            if len(args) > 1:
                new_content = args[1]

        if not note_id:
            return "Feil: Ugyldig notat-ID"

        full_path = resolve_note_path(note_id)

        if full_path and os.path.exists(full_path) and os.path.isfile(full_path):
            with open(full_path, 'w', encoding='utf-8') as f:
                f.write(str(new_content))
            return "OK"

        return f"Feil: Fant ikke filstien for {note_id}"
    except Exception as e:
        return f"Feil ved lagring: {str(e)}"

def create_folder(folder_name=None, *args, **kwargs):
    """Oppretter en undermappe i den aktive notatblokken."""
    if folder_name is None and args:
        folder_name = args[0]

    if not folder_name or not str(folder_name).strip():
        return False

    clean_name = str(folder_name).strip().replace("dir:", "")
    nb_dir = get_active_notebook_dir()

    try:
        target_dir = os.path.join(nb_dir, clean_name)
        os.makedirs(target_dir, exist_ok=True)
        log(f"Opprettet mappe: {target_dir}")
        return True
    except Exception as e:
        log(f"Feil ved opprettelse av mappe: {e}")
        return False

def create_note(content_or_title="", title=None, folder_path=None, *args, **kwargs):
    """Oppretter en ny .md-fil direkte i mappen."""
    if args:
        content_or_title = args[0]
        if len(args) > 1:
            title = args[1]
        if len(args) > 2:
            folder_path = args[2]

    if "content" in kwargs:
        content_or_title = kwargs["content"]
    if "title" in kwargs:
        title = kwargs["title"]
    if "folder" in kwargs or "folder_path" in kwargs:
        folder_path = kwargs.get("folder") or kwargs.get("folder_path")

    nb_dir = get_active_notebook_dir()

    note_content = ""
    target_folder = ""

    if folder_path is not None:
        note_content = str(content_or_title).strip() if content_or_title else ""
        target_folder = str(folder_path).strip()
    elif title is not None and not folder_path:
        note_content = str(content_or_title).strip() if content_or_title else ""
        target_folder = str(title).strip()
    else:
        note_content = str(content_or_title).strip() if content_or_title else ""

    # Tillater nå både quickNotes_root, quickNotes og vanlige rot-termer
    if target_folder in ("/", "quickNotes_root", "Home (Rotmappe)", "Alle mapper", "dir:quickNotes_root", "quickNotes"):
        target_folder = ""

    if target_folder.startswith("dir:"):
        target_folder = target_folder.replace("dir:", "").strip()

    if not note_content:
        return False

    lines = [l.strip() for l in note_content.splitlines() if l.strip()]
    if lines:
        first_line = lines[0].lstrip('#').strip()
        clean_filename = re.sub(r'[\\/*?:"<>|]', "", first_line)
        note_title = clean_filename if clean_filename else "Uten tittel"
    else:
        note_title = "Uten tittel"

    target_dir = os.path.join(nb_dir, target_folder) if target_folder else nb_dir
    os.makedirs(target_dir, exist_ok=True)

    filename = f"{note_title}.md" if not note_title.endswith('.md') else note_title
    file_path = os.path.join(target_dir, filename)

    try:
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(f"{note_content}\n")
        log(f"Opprettet notatfil: {file_path}")
        return True
    except Exception as e:
        log(f"Feil ved lagring av notat: {e}")
        return False

def get_folders(notebook_id=None, *args, **kwargs):
    """
    Henter oversikt over alle mapper i den valgte eller aktive notatblokken.
    Definert med notebook_id=None for å passe både 0 og 1 positional args fra PyOtherSide.
    """
    try:
        notebook_name = notebook_id
        if not notebook_name and args:
            notebook_name = args[0]
        if not notebook_name:
            notebook_name = kwargs.get("notebook") or kwargs.get("notebook_name")

        if notebook_name and str(notebook_name).strip() not in ("ALL", "Alle notatblokker", "Alle notebooks", "Alle mapper", "/", ""):
            nb_dir = os.path.join(get_default_notes_dir(), str(notebook_name).strip())
        else:
            nb_dir = get_active_notebook_dir()

        folders = ["/"]
        if os.path.exists(nb_dir):
            for root, dirs, files in os.walk(nb_dir):
                dirs[:] = [d for d in dirs if not d.startswith('.') and d not in (".basket", ".git")]
                rel_path = os.path.relpath(root, nb_dir)
                if rel_path != ".":
                    folders.append(rel_path)
        return sorted(folders)
    except Exception as e:
        log(f"Feil i get_folders(): {e}")
        return ["/"]

def search_notes(query="", folder="ALL", notebook="ALL", *args, **kwargs):
    """Søker i tekstfilene etter søkeord på tvers av en eller alle notatblokker."""
    try:
        if args:
            query = args[0]
            if len(args) > 1:
                folder = args[1]
            if len(args) > 2:
                notebook = args[2]

        if not query or not str(query).strip():
            return []

        search_term = str(query).strip()
        base_notes_dir = get_default_notes_dir()

        if notebook and str(notebook).strip() not in ("ALL", "Alle notatblokker", "Alle notebooks", ""):
            notebooks_to_search = [str(notebook).strip()]
        else:
            notebooks_to_search = get_notebooks()

        escaped_q = re.escape(search_term)
        pattern = re.compile(escaped_q, re.IGNORECASE)

        results = []

        for nb_name in notebooks_to_search:
            nb_dir = os.path.join(base_notes_dir, nb_name)

            if folder and str(folder).strip() not in ("ALL", "Alle mapper", "/", ""):
                search_root = os.path.join(nb_dir, str(folder).strip())
            else:
                search_root = nb_dir

            if not os.path.exists(search_root):
                continue

            for root, dirs, files in os.walk(search_root):
                dirs[:] = [d for d in dirs if not d.startswith('.') and d not in (".basket", ".git")]

                for file in sorted(files):
                    if file.startswith('.') or file == "config.json":
                        continue

                    full_path = os.path.join(root, file)
                    rel_file_path = os.path.relpath(full_path, base_notes_dir)
                    note_title = extract_title_from_file(full_path)

                    try:
                        with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
                            lines = f.readlines()
                    except Exception:
                        continue

                    matches = []
                    for line in lines:
                        line_str = line.strip()
                        if not line_str:
                            continue

                        for match in pattern.finditer(line_str):
                            start_idx = match.start()
                            end_idx = match.end()

                            words_before = line_str[:start_idx].strip().split()[-3:]
                            words_after = line_str[end_idx:].strip().split()[:3]

                            snippet_str = f"{' '.join(words_before)} [{match.group(0)}] {' '.join(words_after)}"
                            matches.append(snippet_str.strip())

                    title_match = pattern.search(note_title)

                    if matches or title_match:
                        first_snippet = matches[0] if matches else "Treff i filnavn/tittel"
                        extra_matches = max(0, len(matches) - 1)

                        results.append({
                            "title": str(note_title),
                            "path": str(rel_file_path),
                            "full_path": str(full_path),
                            "snippet": str(first_snippet),
                            "extra_matches": extra_matches,
                            "total_matches": len(matches)
                        })

        return results
    except Exception as e:
        log(f"Søkefeil: {e}")
        return [{"title": f"Søkefeil: {str(e)}", "path": "", "snippet": "", "extra_matches": 0, "total_matches": 0}]

# ==============================================================================
# --- PAPIRKURV (.basket) ---
# ==============================================================================

def _get_basket_dir():
    """Returnerer stien til papirkurven."""
    basket_dir = os.path.expanduser("~/.config/NBsail/.basket")
    os.makedirs(basket_dir, exist_ok=True)
    return basket_dir

def delete_item(item_id=None, *args, **kwargs):
    """Flytter fil eller mappe til papirkurven."""
    try:
        if item_id is None and args:
            item_id = args[0]
        if not item_id:
            return "Error: Ugyldig element-ID"

        basket_dir = _get_basket_dir()

        clean_path = str(item_id).replace("dir:", "").strip()

        if clean_path in ("quickNotes_root", "quickNotes", "Home", ""):
            return "Error: Kan ikke slette rotmappen."

        full_path = resolve_note_path(clean_path)

        if not full_path or not os.path.exists(full_path):
            return f"Error: Elementet finnes ikke ({clean_path})"

        timestamp = int(time.time())
        basket_id = f"item_{timestamp}"
        is_dir = os.path.isdir(full_path)

        if is_dir:
            title = os.path.basename(clean_path)
            basket_item_path = os.path.join(basket_dir, basket_id)
            shutil.move(full_path, basket_item_path)
        else:
            title = extract_title_from_file(full_path)
            basket_item_path = os.path.join(basket_dir, f"{basket_id}.file")
            shutil.move(full_path, basket_item_path)

        meta = {
            "basket_id": basket_id,
            "original_rel_path": clean_path,
            "title": title,
            "is_dir": is_dir,
            "deleted_at": timestamp
        }

        meta_path = os.path.join(basket_dir, f"{basket_id}.json")
        with open(meta_path, "w", encoding="utf-8") as f:
            json.dump(meta, f, indent=4, ensure_ascii=False)

        log(f"Flyttet til papirkurv: {clean_path} -> {basket_id}")
        return "OK"
    except Exception as e:
        log(f"Feil ved sletting: {e}")
        return f"Error ved sletting: {str(e)}"

def get_basket_items(*args, **kwargs):
    """Henter elementer i papirkurven."""
    try:
        basket_dir = _get_basket_dir()
        items = []

        for file in os.listdir(basket_dir):
            if file.endswith(".json"):
                meta_path = os.path.join(basket_dir, file)
                try:
                    with open(meta_path, "r", encoding="utf-8") as f:
                        items.append(json.load(f))
                except Exception as e:
                    log(f"Feil ved lesing av papirkurv-meta {file}: {e}")

        items.sort(key=lambda x: x.get("deleted_at", 0), reverse=True)
        return items
    except Exception as e:
        log(f"Feil i get_basket_items: {e}")
        return []

def restore_basket_item(basket_id=None, *args, **kwargs):
    """Gjenoppretter et element fra papirkurven."""
    try:
        if basket_id is None and args:
            basket_id = args[0]
        if not basket_id:
            return "Feil: Ugyldig basket_id"

        nb_dir = get_active_notebook_dir()
        basket_dir = _get_basket_dir()

        meta_path = os.path.join(basket_dir, f"{basket_id}.json")
        if not os.path.exists(meta_path):
            return "Feil: Fant ikke metadata i papirkurven."

        with open(meta_path, "r", encoding="utf-8") as f:
            meta = json.load(f)

        original_rel_path = meta.get("original_rel_path", "")
        is_dir = meta.get("is_dir", False)

        target_full_path = os.path.join(nb_dir, original_rel_path)
        os.makedirs(os.path.dirname(target_full_path), exist_ok=True)

        if is_dir:
            basket_item_path = os.path.join(basket_dir, basket_id)
            if os.path.exists(basket_item_path):
                shutil.move(basket_item_path, target_full_path)
        else:
            basket_item_path = os.path.join(basket_dir, f"{basket_id}.file")
            if os.path.exists(basket_item_path):
                shutil.move(basket_item_path, target_full_path)

        if os.path.exists(meta_path):
            os.remove(meta_path)

        log(f"Gjenopprettet fra papirkurv: {basket_id} -> {original_rel_path}")
        return "OK"
    except Exception as e:
        log(f"Feil ved gjenoppretting: {e}")
        return f"Feil ved gjenoppretting: {str(e)}"

def delete_permanently(basket_id=None, *args, **kwargs):
    """Sletter et element permanent fra papirkurven."""
    try:
        if basket_id is None and args:
            basket_id = args[0]
        if not basket_id:
            return "Feil: Ugyldig basket_id"

        basket_dir = _get_basket_dir()
        meta_path = os.path.join(basket_dir, f"{basket_id}.json")

        if os.path.exists(meta_path):
            with open(meta_path, "r", encoding="utf-8") as f:
                meta = json.load(f)
                is_dir = meta.get("is_dir", False)

            if is_dir:
                item_path = os.path.join(basket_dir, basket_id)
                if os.path.exists(item_path):
                    shutil.rmtree(item_path, ignore_errors=True)
            else:
                item_path = os.path.join(basket_dir, f"{basket_id}.file")
                if os.path.exists(item_path):
                    try:
                        os.remove(item_path)
                    except Exception:
                        pass

            try:
                os.remove(meta_path)
            except Exception:
                pass

        return "OK"
    except Exception as e:
        log(f"Feil ved permanent sletting: {e}")
        return str(e)

def empty_basket(*args, **kwargs):
    """Tømmer papirkurven helt."""
    try:
        basket_dir = _get_basket_dir()
        if os.path.exists(basket_dir):
            for filename in os.listdir(basket_dir):
                file_path = os.path.join(basket_dir, filename)
                try:
                    if os.path.isdir(file_path):
                        shutil.rmtree(file_path, ignore_errors=True)
                    else:
                        os.remove(file_path)
                except Exception as inner_e:
                    log(f"Feil ved sletting av {file_path}: {inner_e}")

        # Forsikre oss om at mappen finnes etter tømming
        os.makedirs(basket_dir, exist_ok=True)
        log("Papirkurven ble tømt.")
        return True
    except Exception as e:
        log(f"Feil ved tømming av papirkurv: {e}")
        return False
