#pragma once

#include <QObject>
#include <QVariantList>

class AiClient;
class EditorSettings;

// The AI pair programmer: a chat about the open file, inline rewrites of a
// selection (Ctrl+K), and one-click actions (explain, fix, document, test).
class Assistant : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList messages READ messages NOTIFY messagesChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(QString provider READ provider WRITE setProvider NOTIFY providerChanged)
    Q_PROPERTY(QString inlineResult READ inlineResult NOTIFY inlineChanged)
    Q_PROPERTY(bool inlineBusy READ inlineBusy NOTIFY inlineChanged)

public:
    Assistant(AiClient *ai, EditorSettings *settings, QObject *parent = nullptr);

    QVariantList messages() const { return m_messages; }
    bool busy() const { return m_busy; }
    QString error() const { return m_error; }
    QString provider() const;
    void setProvider(const QString &provider);
    QString inlineResult() const { return m_inlineResult; }
    bool inlineBusy() const { return m_inlineBusy; }

    // [{key, name, ready, model}] for the provider picker.
    Q_INVOKABLE QVariantList providers() const;
    Q_INVOKABLE void send(const QString &question, const QString &fileName, const QString &language,
                          const QString &fileText, const QString &selection);
    // Predefined requests: explain, fix, document, tests, optimize, review.
    Q_INVOKABLE void quickAction(const QString &kind, const QString &fileName, const QString &language,
                                 const QString &fileText, const QString &selection);
    Q_INVOKABLE void inlineEdit(const QString &instruction, const QString &fileName, const QString &language,
                                const QString &before, const QString &selection, const QString &after);
    Q_INVOKABLE void stop();
    Q_INVOKABLE void clear();
    Q_INVOKABLE void clearInline();
    Q_INVOKABLE void loadModels(const QString &provider);

    // Splits a Markdown answer into [{type: "text"|"code", language, content}].
    Q_INVOKABLE static QVariantList segments(const QString &text);
    // The code inside the first fenced block, or the text itself when there's none.
    static QString unfence(const QString &text);
    static QString quickPrompt(const QString &kind);

signals:
    void messagesChanged();
    void busyChanged();
    void errorChanged();
    void providerChanged();
    void inlineChanged();
    void modelsLoaded(const QString &provider, const QStringList &models, const QString &error);

private:
    void setBusy(bool busy);
    void setError(const QString &error);
    QString systemPrompt() const;

    AiClient *m_ai;
    EditorSettings *m_settings;
    QVariantList m_messages; // {role, text, context}
    bool m_busy = false;
    QString m_error;
    QString m_inlineResult;
    bool m_inlineBusy = false;
    int m_generation = 0;
};
