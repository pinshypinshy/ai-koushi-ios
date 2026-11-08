//
//  APIClient+Fake.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/07.
//

import APIClient
import Models

extension APIClient {
    /// 料金をかけずに画面を確かめるための偽の API（ADR 0006）
    public static var fake: APIClient {
        let server = FakeServer()
        var client = APIClient()
        client.bootstrap = {
            BootstrapResponse(
                user: ApiUser(id: "fake-user", email: "guest@example.com", displayName: "確認用"),
                courses: await server.summaries(),
                selected: await server.course(id: FakeServer.longCourseID),
                usage: UsageSummary(costUsd: 0.1, costLimitUsd: 1, courses: 4, courseLimit: 10, periodStart: 0)
            )
        }
        client.guestLogin = { _, _ in }
        client.logout = {}
        client.course = { id in await server.course(id: id) }
        client.usage = { UsageSummary(costUsd: 0.2, costLimitUsd: 1, courses: 4, courseLimit: 10, periodStart: 0) }
        client.streamLecture = { id in
            fakeStream(server: server, courseID: id, failsBeforeDone: id == FakeServer.failingCourseID)
        }
        client.sendMessage = { id, text in
            fakeStream(server: server, courseID: id, userText: text)
        }
        // 失敗の後に再生成で立て直せることを確かめるため、受信に失敗する講義でも再生成は成功させる
        client.regenerate = { id in
            fakeStream(server: server, courseID: id)
        }
        client.completeStep = { id, stepID in
            try await Task.sleep(for: .seconds(1))
            return await server.completeStep(courseID: id, stepID: stepID)
        }
        // 読み込み中と採点中の表示を見られるように待つ
        client.quiz = { id in
            try await Task.sleep(for: .milliseconds(500))
            return await server.quiz(courseID: id)
        }
        client.attempt = { questionID, choiceID in
            try await Task.sleep(for: .milliseconds(500))
            return try await server.grade(questionID: questionID, choiceID: choiceID)
        }
        return client
    }
}

private func fakeStream(
    server: FakeServer,
    courseID: String,
    userText: String? = nil,
    failsBeforeDone: Bool = false
) -> AsyncThrowingStream<LectureStreamLine, any Error> {
    AsyncThrowingStream { continuation in
        let task = Task {
            do {
                if let userText {
                    await server.appendUserMessage(courseID: courseID, text: userText)
                }
                var text = ""
                for index in 1...(failsBeforeDone ? 5 : 20) {
                    try await Task.sleep(for: .milliseconds(250))
                    let delta = "届いた文字 \(index) "
                    text += delta
                    continuation.yield(.delta(delta))
                }
                if failsBeforeDone {
                    continuation.finish(throwing: APIClientError.network)
                    return
                }
                let message = await server.appendAssistantMessage(courseID: courseID, text: text)
                continuation.yield(.done(message))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}

/// 発言とステップの進みを覚える。読み直しや次のステップの受信で、本物のサーバーと同じ流れを確かめるため
private actor FakeServer {
    static let longCourseID = "c1"
    static let quizPendingCourseID = "c2"
    static let failingCourseID = "c4"

    private static let stepCount = 12

    private var courses: [CourseDetail]
    private var nextMessageNumber = 1
    private var summaryCallCount = 0
    private var latestIsCorrect: [String: Bool] = ["c1-q1": false, "c1-q2": true]
    private var failedQuestionIDs: Set<String> = []

    init() {
        courses = [
            Self.detail(
                id: Self.longCourseID,
                title: "とても長い講義のタイトルで一番上の行に収まらないときに末尾を省く確認",
                currentStep: 2,
                quizStatus: .ready,
                messages: [
                    ApiMessage(id: "m1", stepId: "s2", role: .assistant, content: Self.longText, interrupted: false),
                    ApiMessage(id: "m2", stepId: "s2", role: .user, content: "順番を変えても同じですか？", interrupted: false),
                    ApiMessage(id: "m3", stepId: "s2", role: .assistant, content: "いいえ。**一般に異なります**。", interrupted: false),
                ]
            ),
            Self.detail(id: Self.quizPendingCourseID, title: "発言の無い講義", currentStep: 1, quizStatus: .pending, messages: []),
            CourseDetail(
                summary: Self.summary(id: "c3", title: "生成中の講義", status: .generating, quizStatus: .pending, completedSteps: 0),
                currentStepId: nil,
                steps: [],
                messages: []
            ),
            Self.detail(id: Self.failingCourseID, title: "受信に失敗する講義", currentStep: 1, quizStatus: .failed, messages: []),
        ]
    }

    /// 1回目は起動時の bootstrap、2回目はサイドバーの取り直し。取り直すと確認テストが ready になる（§4.15）
    func summaries() -> [CourseSummary] {
        summaryCallCount += 1
        if summaryCallCount == 2 {
            setQuizStatus(.ready, courseID: Self.quizPendingCourseID)
        }
        return courses.map(\.summary)
    }

    func course(id: String) -> CourseDetail {
        courses.first { $0.summary.id == id } ?? courses[0]
    }

    func appendUserMessage(courseID: String, text: String) {
        let stepID = course(id: courseID).currentStepId ?? "s\(Self.stepCount)"
        append(role: .user, content: text, stepID: stepID, courseID: courseID)
    }

    /// 再生成では途切れた発言が新しい応答に置き換わる（§4.13）
    func appendAssistantMessage(courseID: String, text: String) -> ApiMessage {
        let current = course(id: courseID)
        let stepID = current.currentStepId ?? "s\(Self.stepCount)"
        let kept = current.messages.filter { !($0.interrupted && $0.stepId == stepID) }
        replace(
            CourseDetail(summary: current.summary, currentStepId: current.currentStepId, steps: current.steps, messages: kept)
        )
        return append(role: .assistant, content: text, stepID: stepID, courseID: courseID)
    }

    func completeStep(courseID: String, stepID: String) -> CourseDetail {
        let current = course(id: courseID)
        let nextNumber = (current.steps.first { $0.id == stepID }?.orderIndex ?? 0) + 1
        let next = CourseDetail(
            summary: Self.summary(
                id: courseID,
                title: current.summary.title,
                quizStatus: current.summary.quizStatus,
                completedSteps: nextNumber - 1
            ),
            currentStepId: nextNumber <= Self.stepCount ? "s\(nextNumber)" : nil,
            steps: Self.steps(currentStep: nextNumber),
            messages: current.messages
        )
        replace(next)
        return next
    }

    func quiz(courseID: String) -> QuizResponse {
        guard course(id: courseID).summary.quizStatus == .ready else {
            return QuizResponse(questions: [], latestAttempts: [])
        }
        let questions = FakeQuestion.all.map { $0.apiQuestion(courseID: courseID) }
        return QuizResponse(
            questions: questions,
            latestAttempts: questions.compactMap { question in
                latestIsCorrect[question.id].map { AttemptSummary(questionId: question.id, isCorrect: $0) }
            }
        )
    }

    func grade(questionID: String, choiceID: String) throws -> AttemptResult {
        guard let question = FakeQuestion.all.first(where: { questionID.hasSuffix("-\($0.id)") }) else {
            throw APIClientError.http(status: 404, body: nil)
        }
        if question.failsFirstAttempt, failedQuestionIDs.insert(questionID).inserted {
            throw APIClientError.network
        }
        let isCorrect = choiceID == question.correctChoiceID
        latestIsCorrect[questionID] = isCorrect
        return AttemptResult(
            questionId: questionID,
            selectedChoiceId: choiceID,
            correctChoiceId: question.correctChoiceID,
            isCorrect: isCorrect,
            explanation: question.explanation
        )
    }

    private func setQuizStatus(_ quizStatus: QuizStatus, courseID: String) {
        let current = course(id: courseID)
        let summary = current.summary
        replace(
            CourseDetail(
                summary: CourseSummary(
                    id: summary.id,
                    title: summary.title,
                    status: summary.status,
                    quizStatus: quizStatus,
                    phase: summary.phase,
                    errorMessage: summary.errorMessage,
                    totalSteps: summary.totalSteps,
                    completedSteps: summary.completedSteps,
                    updatedAt: summary.updatedAt
                ),
                currentStepId: current.currentStepId,
                steps: current.steps,
                messages: current.messages
            )
        )
    }

    @discardableResult
    private func append(role: MessageRole, content: String, stepID: String, courseID: String) -> ApiMessage {
        let message = ApiMessage(id: "fake-\(nextMessageNumber)", stepId: stepID, role: role, content: content, interrupted: false)
        nextMessageNumber += 1
        let current = course(id: courseID)
        replace(
            CourseDetail(summary: current.summary, currentStepId: current.currentStepId, steps: current.steps, messages: current.messages + [message])
        )
        return message
    }

    private func replace(_ detail: CourseDetail) {
        guard let index = courses.firstIndex(where: { $0.summary.id == detail.summary.id }) else { return }
        courses[index] = detail
    }

    private static func detail(
        id: String,
        title: String,
        currentStep: Int,
        quizStatus: QuizStatus,
        messages: [ApiMessage]
    ) -> CourseDetail {
        CourseDetail(
            summary: summary(id: id, title: title, quizStatus: quizStatus, completedSteps: currentStep - 1),
            currentStepId: "s\(currentStep)",
            steps: steps(currentStep: currentStep),
            messages: messages
        )
    }

    private static func summary(
        id: String,
        title: String,
        status: CourseStatus = .ready,
        quizStatus: QuizStatus,
        completedSteps: Int
    ) -> CourseSummary {
        CourseSummary(
            id: id,
            title: title,
            status: status,
            quizStatus: quizStatus,
            phase: nil,
            errorMessage: nil,
            totalSteps: stepCount,
            completedSteps: completedSteps,
            updatedAt: 0
        )
    }

    private static func steps(currentStep: Int) -> [ApiStep] {
        (1...stepCount).map { number in
            let status: StepStatus = number < currentStep ? .completed : number == currentStep ? .inProgress : .notStarted
            return ApiStep(id: "s\(number)", orderIndex: number, title: "ステップの題名 \(number)", status: status)
        }
    }

    private static let longText = """
    ## 行列の積

    行列 $A$ と $B$ の積は次のとおりです。[参考リンク](https://example.com/page)

    $$
    \\begin{pmatrix} a_{11} & a_{12} & a_{13} & a_{14} & a_{15} & a_{16} & a_{17} & a_{18} & a_{19} & a_{20} & a_{21} & a_{22} & a_{23} & a_{24} & a_{25} \\end{pmatrix}
    $$


    """ + (1...12).map { "段落 \($0)：一般に $AB \\neq BA$ です。文中の分数 $\\frac{1}{2}$ も確かめます。\n" }.joined(separator: "\n")
}

/// ApiQuestion は正解を含まないため、正解と解説を別に持つ
private struct FakeQuestion {
    let id: String
    let stem: String
    let choices: [String]
    let stepIDs: [String]
    let correctChoiceID: String
    let explanation: String
    var failsFirstAttempt = false

    /// 設問の ID はサーバーと同じく講義をまたいで重ならないよう、講義の ID を前に付ける
    func apiQuestion(courseID: String) -> ApiQuestion {
        ApiQuestion(
            id: "\(courseID)-\(id)",
            stem: stem,
            choices: zip(["a", "b", "c", "d"], choices).map { ApiChoice(id: $0, body: $1) },
            coveredStepIds: stepIDs
        )
    }

    static let all: [FakeQuestion] = [
        FakeQuestion(
            id: "q1",
            stem: #"""
            行列 $A = \begin{pmatrix} 1 & 2 \\ 3 & 4 \end{pmatrix}$ の行列式として正しいものはどれか。

            $$
            \det A = ad - bc
            $$
            """#,
            choices: [#"$-2$"#, #"$2$"#, #"$10$"#, #"$\frac{1}{2}$"#],
            stepIDs: ["s1"],
            correctChoiceID: "a",
            explanation: #"$\det A = 1 \cdot 4 - 2 \cdot 3 = -2$ です。"#
        ),
        FakeQuestion(
            id: "q2",
            stem: "次のうち、横に長い数式を含む選択肢はどれか。",
            choices: [
                #"$\begin{pmatrix} a_{1} & a_{2} & a_{3} & a_{4} & a_{5} & a_{6} & a_{7} & a_{8} & a_{9} & a_{10} & a_{11} & a_{12} & a_{13} & a_{14} & a_{15} \end{pmatrix}$"#,
                "短い選択肢",
                #"$x^{2}$"#,
                "どれでもない",
            ],
            stepIDs: ["s2"],
            correctChoiceID: "a",
            explanation: "枠の中で横にスクロールできることを確かめるための選択肢です。"
        ),
        FakeQuestion(
            id: "q3",
            stem: "長い選択肢が省略されずに折り返されることを確かめる設問です。正しいものはどれか。",
            choices: [
                "これはとても長い選択肢で、画面の幅に収まらないときに省略されず、何行にもわたって折り返されて全文が表示されることを確かめるための文です。",
                "短い選択肢",
                "これも長めの選択肢で、二行ほどに折り返されることを確かめます。",
                "どれでもない",
            ],
            stepIDs: ["s3"],
            correctChoiceID: "a",
            explanation: "長い選択肢も全文を表示します（§3.7）。"
        ),
        FakeQuestion(
            id: "q4",
            stem: "ステップ1とステップ3をまたぐ横断設問です。最初の解答だけ通信エラーになります。",
            choices: ["選択肢A", "選択肢B", "選択肢C", "選択肢D"],
            stepIDs: ["s1", "s3"],
            correctChoiceID: "b",
            explanation: "2回目の解答は成功します。",
            failsFirstAttempt: true
        ),
        FakeQuestion(
            id: "q5",
            stem: "`A.T` が表すものとして正しいものはどれか。",
            choices: ["**転置**した行列", "逆行列", "単位行列", "零行列"],
            stepIDs: ["s2"],
            correctChoiceID: "a",
            explanation: "コードと**強調**が描けることを確かめる解説です。"
        ),
    ]
}
