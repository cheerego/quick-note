import { existsSync, mkdirSync, readFileSync, writeFileSync } from "fs";
import { join } from "path";
import { homedir } from "os";
import { randomUUID } from "crypto";
import { Note } from "./types";

// Shared storage path accessible by both Raycast extension and the floating window app
const NOTES_DIR = join(homedir(), ".quick-notes");
const NOTES_FILE = join(NOTES_DIR, "notes.json");

function ensureStorageExists(): void {
  if (!existsSync(NOTES_DIR)) {
    mkdirSync(NOTES_DIR, { recursive: true });
  }
  if (!existsSync(NOTES_FILE)) {
    writeFileSync(NOTES_FILE, JSON.stringify([], null, 2), "utf-8");
  }
}

export function getNotes(): Note[] {
  ensureStorageExists();
  const data = readFileSync(NOTES_FILE, "utf-8");
  const notes: Note[] = JSON.parse(data);
  // Sort by updatedAt descending (most recent first)
  return notes.sort((a, b) => b.updatedAt - a.updatedAt);
}

export function createNote(title: string, content: string): Note {
  const notes = getNotes();
  const now = Date.now();
  const note: Note = {
    id: randomUUID(),
    title,
    content,
    createdAt: now,
    updatedAt: now,
  };
  notes.push(note);
  saveNotes(notes);
  return note;
}

export function updateNote(
  id: string,
  title: string,
  content: string,
): Note | null {
  const notes = getNotes();
  const index = notes.findIndex((n) => n.id === id);
  if (index === -1) return null;

  notes[index] = {
    ...notes[index],
    title,
    content,
    updatedAt: Date.now(),
  };
  saveNotes(notes);
  return notes[index];
}

export function deleteNote(id: string): boolean {
  const notes = getNotes();
  const filtered = notes.filter((n) => n.id !== id);
  if (filtered.length === notes.length) return false;
  saveNotes(filtered);
  return true;
}

function saveNotes(notes: Note[]): void {
  ensureStorageExists();
  writeFileSync(NOTES_FILE, JSON.stringify(notes, null, 2), "utf-8");
}
