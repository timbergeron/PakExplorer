using System.Windows;
using PakStudio.App.Views;
using PakStudio.Core.Documents;
using PakStudio.Core.Interfaces;

namespace PakStudio.App.Services;

public sealed class MessageBoxService : IMessageBoxService
{
    public void ShowAbout()
    {
        var dialog = new Views.AboutWindow
        {
            Owner = WindowOwnership.ActiveMainWindow(),
        };
        dialog.ShowDialog();
    }

    public ImportConflictDecision ResolveImportConflict(string name, bool isFolder)
    {
        var message = $"An item named '{name}' already exists in this archive folder. " +
            (isFolder ? "Replace removes the existing folder and all its contents. " : "Replace overwrites the existing item. ") +
            "Keep Both adds a renamed copy. Skip leaves this item unchanged. Cancel stops the remaining import.";
        var result = ShowDialog("Replace or Skip Items", message, MessageDialogButtons.ImportConflict);
        return result switch
        {
            MessageDialogResult.KeepBoth => ImportConflictDecision.KeepBoth,
            MessageDialogResult.Skip => ImportConflictDecision.Skip,
            MessageDialogResult.Replace => ImportConflictDecision.Replace,
            _ => ImportConflictDecision.Cancel,
        };
    }

    public void ShowInfo(string title, string message)
    {
        _ = ShowDialog(title, message, MessageDialogButtons.Ok);
    }

    public void ShowError(string title, string message)
    {
        _ = ShowDialog(title, message, MessageDialogButtons.Ok);
    }

    public bool Confirm(string title, string message)
    {
        return ShowDialog(title, message, MessageDialogButtons.ConfirmCancel) ==
               MessageDialogResult.Confirm;
    }

    public SaveChangesDecision ConfirmSaveChanges(string displayName)
    {
        var result = ShowDialog(
            "Unsaved Changes",
            $"Save changes to '{displayName}' before continuing?",
            MessageDialogButtons.SaveDiscardCancel);

        return result switch
        {
            MessageDialogResult.Save => SaveChangesDecision.Save,
            MessageDialogResult.Discard => SaveChangesDecision.Discard,
            _ => SaveChangesDecision.Cancel,
        };
    }

    private static MessageDialogResult ShowDialog(
        string title,
        string message,
        MessageDialogButtons buttons)
    {
        var dialog = new MessageDialogWindow(title, message, buttons);
        if (WindowOwnership.ActiveMainWindow() is { IsVisible: true } owner)
        {
            dialog.Owner = owner;
        }
        return dialog.ShowDialogResult();
    }
}
