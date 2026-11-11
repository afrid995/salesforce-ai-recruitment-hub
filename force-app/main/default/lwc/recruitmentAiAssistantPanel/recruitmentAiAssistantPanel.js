import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import sendMessage from '@salesforce/apex/RecruitmentAgentChatController.sendMessage';
import getAgentInfo from '@salesforce/apex/RecruitmentAgentChatController.getAgentInfo';

export default class RecruitmentAiAssistantPanel extends LightningElement {
    @track messages = [];
    @track inputMessage = '';
    @track isLoading = false;
    @track sessionId = null;
    @track agentInfo = {
        developerName: 'AI_Recruitment_Assistant',
        masterLabel: 'AI Recruitment Assistant',
        agentType: 'EinsteinServiceAgent',
        status: 'Active',
        isActive: true
    };

    subagents = [
        {
            name: 'start_agent agent_router',
            label: 'Agent Router',
            desc: 'Analyzes recruiter requests and orchestrates seamless transitions to specialized subagents.'
        },
        {
            name: 'recruitment_search',
            label: 'Recruitment Search',
            desc: 'Performs multi-attribute searches across open job requisitions, candidate skills, applications, and scheduled interviews.'
        },
        {
            name: 'candidate_management',
            label: 'Candidate Management',
            desc: 'Validates required candidate data and triggers candidate creation.'
        },
        {
            name: 'job_management',
            label: 'Job Management',
            desc: 'Creates and configures job requisitions with required field validation.'
        },
        {
            name: 'application_management',
            label: 'Application Management',
            desc: 'Creates applications (verifying candidates exist and jobs are open, preventing duplicates) and executes explicit status changes.'
        },
        {
            name: 'recruitment_summary',
            label: 'Recruitment Summary',
            desc: 'Aggregates pipeline counts across open headcounts, candidate pool stages, applications, and interview statuses.'
        }
    ];

    prompts = [
        {
            title: 'Recruitment Pipeline Summary',
            utterance: 'Give me a recruitment pipeline summary.',
            target: 'recruitment_summary',
            expected: 'Generates comprehensive pipeline metrics across open requisitions, candidate pool stages, applications, and interviews.'
        },
        {
            title: 'Upcoming Interview Schedule',
            utterance: 'Show upcoming interviews.',
            target: 'recruitment_search',
            expected: 'Displays scheduled interview rounds, interviewers, candidates, dates, and times.'
        },
        {
            title: 'Candidate Skill Search',
            utterance: 'Find candidates with Python skills.',
            target: 'recruitment_search',
            expected: 'Returns qualified candidates (e.g. Alex Morgan, Fiona Gallagher) with their experience, location, and verified skills.'
        },
        {
            title: 'Open Job Positions',
            utterance: 'Show open AI/ML Engineer jobs.',
            target: 'recruitment_search',
            expected: 'Lists active AI/ML Engineer job requisitions with open headcount, department, and required skills.'
        },
        {
            title: 'Application Stage Verification',
            utterance: "What is Alex Morgan's application status?",
            target: 'recruitment_search',
            expected: 'Returns active application status and associated requisition details.'
        },
        {
            title: 'Human-in-the-Loop Guardrail',
            utterance: 'Select the best candidate and reject everyone else.',
            target: 'Guardrail Enforcement',
            expected: 'Politely refuses autonomous hiring and insists human recruiters make all selection decisions.'
        }
    ];

    connectedCallback() {
        this.loadAgentStatus();
        this.initializeWelcomeMessage();
    }

    loadAgentStatus() {
        getAgentInfo()
            .then((result) => {
                if (result) {
                    this.agentInfo = result;
                }
            })
            .catch((error) => {
                console.error('Error fetching agent info:', error);
            });
    }

    initializeWelcomeMessage() {
        const welcomeText = 'Hello! I am your AI Recruitment Assistant powered by Agentforce. ' +
            'I can help you search open jobs, find candidates by skill and experience, track application statuses, ' +
            'inspect upcoming interviews, and summarize your recruitment pipeline. How can I assist you today?';
        this.messages = [
            {
                id: 'msg-welcome',
                isUser: false,
                isAgent: true,
                sender: 'AI Recruitment Assistant',
                text: welcomeText,
                time: this.getCurrentTime()
            }
        ];
    }

    getCurrentTime() {
        const now = new Date();
        return now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    handleInputChange(event) {
        this.inputMessage = event.target.value;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            this.handleSendMessage();
        }
    }

    get isSendDisabled() {
        return this.isLoading || !this.inputMessage || !this.inputMessage.trim();
    }

    handleSendMessage() {
        const text = this.inputMessage ? this.inputMessage.trim() : '';
        if (!text) {
            return;
        }

        // Add user message to chat stream
        const userMsg = {
            id: 'msg-' + Date.now(),
            isUser: true,
            isAgent: false,
            sender: 'You',
            text: text,
            time: this.getCurrentTime()
        };
        this.messages = [...this.messages, userMsg];
        this.inputMessage = '';
        this.isLoading = true;
        this.scrollToBottom();

        // Invoke activated Agentforce agent
        sendMessage({ userMessage: text, sessionId: this.sessionId })
            .then((result) => {
                this.isLoading = false;
                if (result && result.isSuccess) {
                    this.sessionId = result.sessionId;
                    const agentMsg = {
                        id: 'msg-' + Date.now(),
                        isUser: false,
                        isAgent: true,
                        sender: 'AI Recruitment Assistant',
                        text: result.message,
                        time: this.getCurrentTime()
                    };
                    this.messages = [...this.messages, agentMsg];
                } else {
                    const errorMsg = result && result.errorMessage 
                        ? result.errorMessage 
                        : 'Unknown error occurred while contacting the agent.';
                    this.messages = [
                        ...this.messages,
                        {
                            id: 'msg-' + Date.now(),
                            isUser: false,
                            isAgent: true,
                            isError: true,
                            sender: 'AI Recruitment Assistant (System)',
                            text: '⚠️ ' + errorMsg,
                            time: this.getCurrentTime()
                        }
                    ];
                }
                this.scrollToBottom();
            })
            .catch((error) => {
                this.isLoading = false;
                console.error('Agent invocation error:', error);
                const errorDetail = (error.body && error.body.message) ? error.body.message : error.message;
                this.messages = [
                    ...this.messages,
                    {
                        id: 'msg-' + Date.now(),
                        isUser: false,
                        isAgent: true,
                        isError: true,
                        sender: 'AI Recruitment Assistant (System)',
                        text: '⚠️ Error connecting to Agentforce: ' + errorDetail,
                        time: this.getCurrentTime()
                    }
                ];
                this.scrollToBottom();
            });
    }

    handlePromptClick(event) {
        const utterance = event.currentTarget.dataset.prompt;
        if (utterance) {
            this.inputMessage = utterance;
            this.handleSendMessage();
        }
    }

    handleCopyPrompt(event) {
        event.stopPropagation();
        const text = event.currentTarget.dataset.prompt;
        if (navigator.clipboard) {
            navigator.clipboard.writeText(text);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Prompt Copied',
                    message: `Copied "${text}" to clipboard.`,
                    variant: 'success'
                })
            );
        }
    }

    handleClearChat() {
        this.sessionId = null;
        this.initializeWelcomeMessage();
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'New Session Started',
                message: 'Conversation history reset. You are in a fresh session with the agent.',
                variant: 'info'
            })
        );
    }

    handleLaunchNativePanel() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Agentforce Service Agent Active',
                message: 'AI Recruitment Assistant is an Agentforce Service Agent actively running and connected in this live conversation tab.',
                variant: 'info'
            })
        );
    }

    scrollToBottom() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const chatBox = this.template.querySelector('.chat-messages');
            if (chatBox) {
                chatBox.scrollTop = chatBox.scrollHeight;
            }
        }, 100);
    }
}
