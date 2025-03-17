import * as vscode from 'vscode';
import * as net from 'net';

interface MessageHeader {
    version: number;
    type: number;
    length: number;
}

enum MessageType {
    Eval = 1,
    Result = 2,
    Error = 3
}

class VibeREPLClient {
    private socket: net.Socket | null = null;
    private outputChannel: vscode.OutputChannel;
    private messageQueue: { resolve: (value: string) => void, reject: (reason: any) => void }[] = [];
    private buffer = Buffer.alloc(0);

    constructor() {
        this.outputChannel = vscode.window.createOutputChannel('Vibe REPL');
    }

    async connect(host: string, port: number): Promise<void> {
        return new Promise((resolve, reject) => {
            this.socket = new net.Socket();
            
            this.socket.on('connect', () => {
                this.outputChannel.appendLine(`Connected to Vibe REPL at ${host}:${port}`);
                resolve();
            });

            this.socket.on('data', (data: Buffer) => {
                this.buffer = Buffer.concat([this.buffer, data]);
                this.processBuffer();
            });

            this.socket.on('error', (err) => {
                this.outputChannel.appendLine(`Error: ${err.message}`);
                if (this.messageQueue.length > 0) {
                    this.messageQueue[0].reject(err);
                    this.messageQueue.shift();
                }
            });

            this.socket.connect(port, host);
        });
    }

    private processBuffer() {
        while (this.buffer.length >= 16) { // Size of header
            const header = this.readHeader();
            if (!header) return;

            if (this.buffer.length < 16 + header.length) return;

            const payload = this.buffer.slice(16, 16 + header.length).toString('utf8');
            this.buffer = this.buffer.slice(16 + header.length);

            if (this.messageQueue.length > 0) {
                const { resolve } = this.messageQueue.shift()!;
                resolve(payload);
            }

            this.outputChannel.appendLine(payload);
        }
    }

    private readHeader(): MessageHeader | null {
        if (this.buffer.length < 16) return null;

        return {
            version: this.buffer.readInt32LE(0),
            type: this.buffer.readInt32LE(4),
            length: Number(this.buffer.readBigInt64LE(8))
        };
    }

    async evaluate(code: string): Promise<string> {
        return new Promise((resolve, reject) => {
            if (!this.socket) {
                reject(new Error('Not connected to REPL'));
                return;
            }

            const header = Buffer.alloc(16);
            header.writeInt32LE(1, 0); // version
            header.writeInt32LE(MessageType.Eval, 4); // type
            header.writeBigInt64LE(BigInt(Buffer.byteLength(code)), 8); // length

            this.messageQueue.push({ resolve, reject });
            this.socket.write(Buffer.concat([header, Buffer.from(code)]));
        });
    }

    disconnect() {
        if (this.socket) {
            this.socket.end();
            this.socket = null;
        }
    }

    show() {
        this.outputChannel.show();
    }
}

export function activate(context: vscode.ExtensionContext) {
    const replClient = new VibeREPLClient();

    let disposable = vscode.commands.registerCommand('vibe.startRepl', async () => {
        const terminal = vscode.window.createTerminal('Vibe REPL Server');
        terminal.sendText('vibe --repl');
        terminal.show();

        // Wait a bit for the server to start
        await new Promise(resolve => setTimeout(resolve, 1000));

        try {
            await replClient.connect('localhost', 7654);
            vscode.window.showInformationMessage('Vibe REPL started and connected');
        } catch (err) {
            vscode.window.showErrorMessage(`Failed to connect to Vibe REPL: ${err.message}`);
        }
    });

    context.subscriptions.push(disposable);

    disposable = vscode.commands.registerCommand('vibe.connectRepl', async () => {
        const host = await vscode.window.showInputBox({
            prompt: 'Enter REPL host',
            value: 'localhost'
        });

        const portStr = await vscode.window.showInputBox({
            prompt: 'Enter REPL port',
            value: '7654'
        });

        if (!host || !portStr) return;

        const port = parseInt(portStr, 10);
        if (isNaN(port)) {
            vscode.window.showErrorMessage('Invalid port number');
            return;
        }

        try {
            await replClient.connect(host, port);
            vscode.window.showInformationMessage('Connected to Vibe REPL');
        } catch (err) {
            vscode.window.showErrorMessage(`Failed to connect to Vibe REPL: ${err.message}`);
        }
    });

    context.subscriptions.push(disposable);

    disposable = vscode.commands.registerCommand('vibe.evalBuffer', async () => {
        const editor = vscode.window.activeTextEditor;
        if (!editor) return;

        const document = editor.document;
        const text = document.getText();

        try {
            await replClient.evaluate(text);
        } catch (err) {
            vscode.window.showErrorMessage(`Evaluation failed: ${err.message}`);
        }
    });

    context.subscriptions.push(disposable);

    disposable = vscode.commands.registerCommand('vibe.evalSelection', async () => {
        const editor = vscode.window.activeTextEditor;
        if (!editor) return;

        const selection = editor.selection;
        const text = editor.document.getText(selection);

        try {
            await replClient.evaluate(text);
        } catch (err) {
            vscode.window.showErrorMessage(`Evaluation failed: ${err.message}`);
        }
    });

    context.subscriptions.push(disposable);
}

export function deactivate() {
    // Clean up code here
} 