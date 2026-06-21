import {
  Form,
  ActionPanel,
  Action,
  showToast,
  Toast,
  useNavigation,
  Icon,
} from "@raycast/api";
import { useState } from "react";
import { createNote, updateNote } from "./storage";
import { Note } from "./types";

interface NoteFormProps {
  note?: Note;
  onSave?: () => void;
}

export function NoteForm({ note, onSave }: NoteFormProps) {
  const { pop } = useNavigation();
  const [title, setTitle] = useState(note?.title ?? "");
  const [content, setContent] = useState(note?.content ?? "");

  const isEditing = !!note;

  async function handleSubmit() {
    if (!title.trim()) {
      await showToast({
        style: Toast.Style.Failure,
        title: "Title is required",
      });
      return;
    }

    if (isEditing) {
      updateNote(note.id, title.trim(), content);
      await showToast({ style: Toast.Style.Success, title: "Note updated" });
    } else {
      createNote(title.trim(), content);
      await showToast({ style: Toast.Style.Success, title: "Note created" });
    }

    onSave?.();
    pop();
  }

  return (
    <Form
      navigationTitle={isEditing ? "Edit Note" : "Create Note"}
      actions={
        <ActionPanel>
          <Action.SubmitForm
            title={isEditing ? "Save Changes" : "Create Note"}
            icon={Icon.Check}
            onSubmit={handleSubmit}
          />
        </ActionPanel>
      }
    >
      <Form.TextField
        id="title"
        title="Title"
        placeholder="Note title"
        value={title}
        onChange={setTitle}
      />
      <Form.TextArea
        id="content"
        title="Content"
        placeholder="Write your note here... (Markdown supported)"
        value={content}
        onChange={setContent}
        enableMarkdown
      />
    </Form>
  );
}

export default function CreateNote() {
  return <NoteForm />;
}
