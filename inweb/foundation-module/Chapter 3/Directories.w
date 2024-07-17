[Directories::] Directories.

Scanning directories on the host filing system.

@ All of this abstracts the code already found in the platform definitions.

=
typedef struct scan_directory {
	void *directory_handle;
	char directory_name_written_out[4*MAX_FILENAME_LENGTH];
	CLASS_DEFINITION
} scan_directory;

@ The directory name going out has to be transcoded from flat Unicode to
whatever the locale encoding is; the filenames coming back have to be
transcoded the other way.

=
scan_directory *Directories::open_from(text_stream *name) {
	scan_directory *D = CREATE(scan_directory);
	Str::copy_to_locale_string(D->directory_name_written_out, name, 4*MAX_FILENAME_LENGTH);
	D->directory_handle = Platform::opendir(D->directory_name_written_out);
	if (D->directory_handle == NULL) return NULL;
	return D;
}

scan_directory *Directories::open(pathname *P) {
	TEMPORARY_TEXT(pn)
	WRITE_TO(pn, "%p", P);
	scan_directory *D = Directories::open_from(pn);
	DISCARD_TEXT(pn)
	return D;
}

int Directories::next(scan_directory *D, text_stream *leafname) {
	char leafname_Cs[MAX_FILENAME_LENGTH];
	int rv = TRUE;
	while (rv) {
		rv = Platform::readdir(D->directory_handle, D->directory_name_written_out, leafname_Cs);
		if (leafname_Cs[0] != '.') break;
	}
	Str::clear(leafname);
	if (rv) Streams::write_locale_string(leafname, leafname_Cs);
	return rv;
}

void Directories::close(scan_directory *D) {
	Platform::closedir(D->directory_handle);
}

@ Incredibly, this seems to be the most portable method for testing whether a
directory exists in the file system:

=
int Directories::exists(pathname *P) {
	scan_directory *TRY = Directories::open(P);
	if (TRY == NULL) return FALSE;
	Directories::close(TRY);
	return TRUE;
}

@ It turns out to be useful to scan the contents of a directory in an order
which is predictable regardless of platform -- |Platform::readdir| works in a
different order on MacOS, Windows and Linux, even given the same directory
of files to work on. So the following returns a linked list of the contents,
sorted into alphabetical order, but case-insensitively. For the Inform project,
at least, we don't anticipate ever dealing with files whose names disagree only
in casing, so this ordering is effectively deterministic.

There's some time and memory overhead here, but unless we're dealing with
directories holding upwards of 10,000 files or so, it'll be trivial.

=
linked_list *Directories::listing(pathname *P) {
	int capacity = 4, used = 0;
	text_stream **listing_array = (text_stream **)
		(Memory::calloc(capacity, sizeof(text_stream *), ARRAY_SORTING_MREASON));
	scan_directory *D = Directories::open(P);
	if (D) {
		text_stream *entry = Str::new();
		while (Directories::next(D, entry)) {
			if (used == capacity) {
				int new_capacity = 4*capacity;
				text_stream **new_listing_array = (text_stream **)
					(Memory::calloc(new_capacity, sizeof(text_stream *), ARRAY_SORTING_MREASON));
				for (int i=0; i<used; i++) new_listing_array[i] = listing_array[i];
				listing_array = new_listing_array;
				capacity = new_capacity;
			}
			listing_array[used++] = entry;
			entry = Str::new();
		}
		Directories::close(D);
	}
	qsort(listing_array, (size_t) used, sizeof(text_stream *), Directories::compare_names);
	linked_list *L = NEW_LINKED_LIST(text_stream);
	for (int i=0; i<used; i++) ADD_TO_LINKED_LIST(listing_array[i], text_stream, L);
	Memory::I7_free(listing_array, ARRAY_SORTING_MREASON, capacity*((int) sizeof(text_stream *)));
	return L;
}

int Directories::compare_names(const void *ent1, const void *ent2) {
	text_stream *tx1 = *((text_stream **) ent1);
	text_stream *tx2 = *((text_stream **) ent2);
	return Str::cmp_insensitive(tx1, tx2);
}

@ This is intentionally limited so that it can only rename a directory in place,
that is, change its leafname: it cannot move a directory elsewhere in the file system.
If it succeeds, the pathname |P| is altered to match the new directory name, and
the function returns |TRUE|; if not, |P| is unchanged, and |FALSE|.

=
int Directories::rename(pathname *P, text_stream *new_name) {
	text_stream *old_name = Pathnames::directory_name(P);
	if (Str::eq(old_name, new_name)) return TRUE;
	pathname *Q = Pathnames::down(Pathnames::up(P), new_name);
	TEMPORARY_TEXT(old_path)
	TEMPORARY_TEXT(new_path)
	WRITE_TO(old_path, "%p", P);
	WRITE_TO(new_path, "%p", Q);
	char old_name_written_out[4*MAX_FILENAME_LENGTH];
	Str::copy_to_locale_string(old_name_written_out, old_path, 4*MAX_FILENAME_LENGTH);
	char new_name_written_out[4*MAX_FILENAME_LENGTH];
	Str::copy_to_locale_string(new_name_written_out, new_path, 4*MAX_FILENAME_LENGTH);
	int rv = Platform::rename_directory(old_name_written_out, new_name_written_out);
	if (rv) {
		Str::clear(P->intermediate);
		Str::copy(P->intermediate, new_name);
	}
	DISCARD_TEXT(old_path)
	DISCARD_TEXT(new_path)
	return rv;
}

@ Be careful with this: it amounts to recursive |rm|. It takes out all files
with the given file extension, e.g., |I".txt"|, from the directory and,
potentially, any subdirectories. If a null |extension| is supplied, it takes
out all files that do have some extension. (This is less likely to be something
really awkward, like a symlink.)

=
int Directories::delete_contents(pathname *P, text_stream *extension) {
	return Directories::delete_contents_inner(P, extension, FALSE);
}

int Directories::delete_contents_recursively(pathname *P, text_stream *extension) {
	return Directories::delete_contents_inner(P, extension, TRUE);
}

int Directories::delete_contents_inner(pathname *P, text_stream *extension, int recurse) {
	linked_list *L = Directories::listing(P);
	text_stream *entry;
	LOOP_OVER_LINKED_LIST(entry, text_stream, L) {
		if (Platform::is_folder_separator(Str::get_last_char(entry))) {
			if (recurse) {
				Str::delete_last_character(entry);
				Directories::delete_contents_inner(Pathnames::down(P, entry), extension, recurse);
			}
		} else {
			filename *F = Filenames::in(P, entry);
			TEMPORARY_TEXT(ext)
			Filenames::write_extension(ext, F);
			if (((Str::len(extension) == 0) && (Str::len(ext) > 0)) ||
				(Str::eq(extension, ext)))
				BinaryFiles::delete(F);
			DISCARD_TEXT(ext)
		}
	}
	return 0;
}
