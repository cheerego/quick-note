import {
  List,
  ActionPanel,
  Action,
  Icon,
  confirmAlert,
  Alert,
  showToast,
  Toast,
} from "@raycast/api";
import { useState, useCallback } from "react";
import { getNotes, deleteNote } from "./storage";
import { Note } from "./types";
import { NoteForm } from "./create-note";

export default function SearchNotes() {
  const [notes, setNotes] = useState<Note[]>(getNotes());

  const refreshNotes = useCallback(() => {
    setNotes(getNotes());
  }, []);

  const handleDelete = useCallback(
    async (note: Note) => {
      const confirmed = await confirmAlert({
        title: "Delete Note",
        message: `Are you sure you want to delete "${note.title}"?`,
        primaryAction: {
          title: "Delete",
          style: Alert.ActionStyle.Destructive,
        },
      });

      if (confirmed) {
        deleteNote(note.id);
        refreshNotes();
        await showToast({ style: Toast.Style.Success, title: "Note deleted" });
      }
    },
    [refreshNotes],
  );

  const formatDate = (timestamp: number): string => {
    return new Date(timestamp).toLocaleString();
  };

  return (
    <List isShowingDetail searchBarPlaceholder="Search notes...">
      {notes.length === 0 ? (
        <List.EmptyView
          title="No Notes Yet"
          description="Press ⌘+N to create your first note"
          icon={Icon.Document}
        />
      ) : (
        notes.map((note) => (
          <List.Item
            key={note.id}
            title={note.title}
            keywords={[note.title, note.content]}
            accessories={[{ date: new Date(note.updatedAt) }]}
            detail={
              <List.Item.Detail
                markdown={note.content || "*Empty note*"}
                metadata={
                  <List.Item.Detail.Metadata>
                    <List.Item.Detail.Metadata.Label
                      title="Created"
                      text={formatDate(note.createdAt)}
                    />
                    <List.Item.Detail.Metadata.Label
                      title="Updated"
                      text={formatDate(note.updatedAt)}
                    />
                  </List.Item.Detail.Metadata>
                }
              />
            }
            actions={
              <ActionPanel>
                <Action.Push
                  title="Edit Note"
                  icon={Icon.Pencil}
                  target={<NoteForm note={note} onSave={refreshNotes} />}
                />
                <Action.Push
                  title="Create Note"
                  icon={Icon.Plus}
                  shortcut={{ modifiers: ["cmd"], key: "n" }}
                  target={<NoteForm onSave={refreshNotes} />}
                />
                <Action.CopyToClipboard
                  title="Copy Content"
                  content={note.content}
                  shortcut={{ modifiers: ["cmd"], key: "c" }}
                />
                <Action.CopyToClipboard
                  title="Copy Title"
                  content={note.title}
                  shortcut={{ modifiers: ["cmd", "shift"], key: "c" }}
                />
                <Action
                  title="Delete Note"
                  icon={Icon.Trash}
                  style={Action.Style.Destructive}
                  shortcut={{ modifiers: ["cmd"], key: "d" }}
                  onAction={() => handleDelete(note)}
                />
              </ActionPanel>
            }
          />
        ))
      )}
    </List>
  );
}
