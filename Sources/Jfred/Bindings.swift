import JfredCore
import SwiftUI

extension AppModel {
    func bind<T: Sendable>(_ keyPath: ReferenceWritableKeyPath<AppModel, T>) -> Binding<T> {
        Binding(
            get: { MainActor.assumeIsolated { self[keyPath: keyPath] } },
            set: { newValue in MainActor.assumeIsolated { self[keyPath: keyPath] = newValue } }
        )
    }

    func bindPref<T: Sendable>(_ keyPath: WritableKeyPath<Preferences, T>) -> Binding<T> {
        Binding(
            get: { MainActor.assumeIsolated { self.preferences[keyPath: keyPath] } },
            set: { newValue in MainActor.assumeIsolated { self.preferences[keyPath: keyPath] = newValue } }
        )
    }

    func bindElement(_ keyPath: WritableKeyPath<Preferences, [String]>, _ index: Int) -> Binding<String> {
        Binding(
            get: { MainActor.assumeIsolated { self.preferences[keyPath: keyPath].indices.contains(index) ? self.preferences[keyPath: keyPath][index] : "" } },
            set: { newValue in
                MainActor.assumeIsolated {
                    var list = self.preferences[keyPath: keyPath]
                    guard list.indices.contains(index) else { return }
                    list[index] = newValue
                    self.preferences[keyPath: keyPath] = list
                }
            }
        )
    }

    func bindSystemKeyword(_ id: String, default fallback: String) -> Binding<String> {
        Binding(
            get: { MainActor.assumeIsolated { self.preferences.systemKeywords[id] ?? fallback } },
            set: { newValue in
                MainActor.assumeIsolated {
                    let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty {
                        self.preferences.systemKeywords.removeValue(forKey: id)
                    } else {
                        self.preferences.systemKeywords[id] = trimmed
                    }
                }
            }
        )
    }

    func bindMember(_ keyPath: WritableKeyPath<Preferences, [String]>, _ value: String) -> Binding<Bool> {
        Binding(
            get: { MainActor.assumeIsolated { self.preferences[keyPath: keyPath].contains(value) } },
            set: { on in
                MainActor.assumeIsolated {
                    var list = self.preferences[keyPath: keyPath]
                    if on {
                        if !list.contains(value) { list.append(value) }
                    } else {
                        list.removeAll { $0 == value }
                    }
                    self.preferences[keyPath: keyPath] = list
                }
            }
        )
    }

    func bindWeb<T: Sendable>(_ index: Int, _ keyPath: WritableKeyPath<WebSearch, T>) -> Binding<T> {
        Binding(
            get: { MainActor.assumeIsolated { self.preferences.webSearches[index][keyPath: keyPath] } },
            set: { newValue in
                MainActor.assumeIsolated {
                    guard self.preferences.webSearches.indices.contains(index) else { return }
                    self.preferences.webSearches[index][keyPath: keyPath] = newValue
                }
            }
        )
    }

    func bindSnippet<T: Sendable>(_ index: Int, _ keyPath: WritableKeyPath<Snippet, T>) -> Binding<T> {
        Binding(
            get: { MainActor.assumeIsolated { self.snippets[index][keyPath: keyPath] } },
            set: { newValue in
                MainActor.assumeIsolated {
                    guard self.snippets.indices.contains(index) else { return }
                    self.snippets[index][keyPath: keyPath] = newValue
                }
            }
        )
    }

    func bindWorkflow<T: Sendable>(_ id: UUID, _ keyPath: WritableKeyPath<Workflow, T>) -> Binding<T> {
        Binding(
            get: { MainActor.assumeIsolated { self.workflows.first { $0.id == id }![keyPath: keyPath] } },
            set: { newValue in
                MainActor.assumeIsolated {
                    guard let index = self.workflows.firstIndex(where: { $0.id == id }) else { return }
                    self.workflows[index][keyPath: keyPath] = newValue
                }
            }
        )
    }

    func bindAction<T: Sendable>(_ id: UUID, _ index: Int, _ keyPath: WritableKeyPath<WorkflowAction, T>) -> Binding<T> {
        Binding(
            get: { MainActor.assumeIsolated { self.workflows.first { $0.id == id }!.actions[index][keyPath: keyPath] } },
            set: { newValue in
                MainActor.assumeIsolated {
                    guard let workflowIndex = self.workflows.firstIndex(where: { $0.id == id }),
                          self.workflows[workflowIndex].actions.indices.contains(index) else { return }
                    self.workflows[workflowIndex].actions[index][keyPath: keyPath] = newValue
                }
            }
        )
    }

    func beginWorkflowEdit(_ workflow: Workflow) {
        if let existing = workflows.first(where: { $0.id == workflow.id }) {
            workflowSnapshot = existing
            workflowIsNew = false
        } else {
            workflows.append(workflow)
            workflowSnapshot = nil
            workflowIsNew = true
        }
        editingWorkflowID = workflow.id
        selectedWorkflow = workflow.id
        workflowSelection = nil
    }

    func cancelWorkflowEdit() {
        guard let id = editingWorkflowID else { return }
        if workflowIsNew {
            workflows.removeAll { $0.id == id }
            selectedWorkflow = workflows.first?.id
        } else if let snapshot = workflowSnapshot, let index = workflows.firstIndex(where: { $0.id == id }) {
            workflows[index] = snapshot
        }
        editingWorkflowID = nil
        workflowSnapshot = nil
        workflowIsNew = false
        workflowSelection = nil
    }

    func saveWorkflowEdit() {
        editingWorkflowID = nil
        workflowSnapshot = nil
        workflowIsNew = false
        workflowSelection = nil
        workflowsChanged()
    }
}
