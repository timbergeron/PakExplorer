using PakStudio.Core.Documents;

namespace PakStudio.Core.Interfaces;

public interface IMessageBoxService
{
    void ShowAbout();

    void ShowInfo(string title, string message);

    void ShowError(string title, string message);

    ImportConflictDecision ResolveImportConflict(string name, bool isFolder);

    bool Confirm(string title, string message);

    SaveChangesDecision ConfirmSaveChanges(string displayName);
}
