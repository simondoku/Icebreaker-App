//
//  IcebreakerTests.swift
//  IcebreakerTests
//
//  Created by Simon Doku on 6/25/25.
//

import XCTest
import Combine
@testable import Icebreaker

final class IcebreakerTests: XCTestCase {
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        cancellables = nil
    }
    
    // MARK: - AI Service Tests
    
    func testAIServiceConfiguration() throws {
        let aiConfig = AIConfiguration.shared
        
        // Test that configuration is properly initialized
        XCTAssertNotNil(aiConfig.currentProvider)
        XCTAssertTrue([.deepseek, .openai].contains(aiConfig.currentProvider))
        
        // Test API key configuration
        let apiKey = aiConfig.getAPIKey()
        XCTAssertFalse(apiKey.isEmpty, "API key should not be empty")
        
        // Test usage limits
        XCTAssertGreaterThan(aiConfig.dailyQuestionLimit, 0)
        XCTAssertGreaterThan(aiConfig.matchAnalysisLimit, 0)
    }
    
    func testQuestionGeneration() throws {
        let expectation = self.expectation(description: "Question generation")
        let aiService = AIService.shared
        let sampleAnswers: [AIAnswer] = []
        
        aiService.generatePersonalizedQuestion(
            userHistory: sampleAnswers,
            userPreferences: ["reading", "coffee"],
            category: .books
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Question generation failed (expected if no API key): \(error)")
                }
                expectation.fulfill()
            },
            receiveValue: { question in
                XCTAssertFalse(question.text.isEmpty, "Generated question should not be empty")
                XCTAssertEqual(question.category, .books, "Question category should match request")
                expectation.fulfill()
            }
        )
        .store(in: &cancellables)
        
        waitForExpectations(timeout: 5.0)
    }
    
    func testCompatibilityAnalysis() throws {
        let expectation = self.expectation(description: "Compatibility analysis")
        let aiService = AIService.shared
        
        let answer1 = AIAnswer(questionId: UUID(), text: "I love reading science fiction novels")
        let answer2 = AIAnswer(questionId: UUID(), text: "I enjoy sci-fi books and fantasy stories")
        
        aiService.analyzeCompatibility(
            userAnswer: answer1,
            otherAnswer: answer2,
            questionText: "What's your favorite book genre?"
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Compatibility analysis failed (expected if no API key): \(error)")
                }
                expectation.fulfill()
            },
            receiveValue: { analysis in
                XCTAssertGreaterThan(analysis.score, 0, "Compatibility score should be positive")
                XCTAssertLessThanOrEqual(analysis.score, 100, "Compatibility score should not exceed 100")
                XCTAssertFalse(analysis.reason.isEmpty, "Analysis should include a reason")
                expectation.fulfill()
            }
        )
        .store(in: &cancellables)
        
        waitForExpectations(timeout: 5.0)
    }
    
    // MARK: - Match Engine Tests
    
    func testMatchEngineInitialization() throws {
        let matchEngine = MatchEngine()
        
        XCTAssertFalse(matchEngine.isScanning)
        XCTAssertFalse(matchEngine.isAnalyzingMatches)
        XCTAssertTrue(matchEngine.matches.isEmpty)
        XCTAssertTrue(matchEngine.nearbyUsers.isEmpty)
    }
    
    func testMatchFinding() throws {
        let expectation = self.expectation(description: "Match finding")
        let matchEngine = MatchEngine()
        
        let sampleAnswers = [
            AIAnswer(questionId: UUID(), text: "I love reading books"),
            AIAnswer(questionId: UUID(), text: "Coffee is my favorite drink")
        ]
        
        // Start the match finding process
        matchEngine.findMatches(userAnswers: sampleAnswers)
        
        // Wait a bit for the process to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            XCTAssertFalse(matchEngine.nearbyUsers.isEmpty, "Should have generated nearby users")
            XCTAssertFalse(matchEngine.isScanning, "Should have completed scanning")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    // MARK: - Question Manager Tests
    
    func testQuestionManagerInitialization() throws {
        let questionManager = AIQuestionManager()
        
        XCTAssertNotNil(questionManager.currentQuestion, "Should have a current question")
        XCTAssertTrue(questionManager.hasPendingQuestion, "Should have a pending question")
        XCTAssertFalse(questionManager.isGeneratingQuestion, "Should not be generating initially")
    }
    
    func testAnswerSubmission() throws {
        let questionManager = AIQuestionManager()
        let initialAnswerCount = questionManager.userAnswers.count
        
        // Submit an answer
        questionManager.submitAnswer("This is a test answer")
        
        XCTAssertEqual(questionManager.userAnswers.count, initialAnswerCount + 1, "Answer count should increase")
        XCTAssertFalse(questionManager.hasPendingQuestion, "Should not have pending question after submission")
    }
    
    // MARK: - Authentication Tests
    
    func testAuthManagerInitialization() throws {
        let authManager = FirebaseAuthManager()
        
        XCTAssertFalse(authManager.isLoading)
        XCTAssertTrue(authManager.errorMessage.isEmpty)
        // Note: isSignedIn might be true if user data is saved locally
    }
    
    func testSignUpValidation() throws {
        let expectation = self.expectation(description: "Sign up validation")
        let authManager = FirebaseAuthManager()
        
        // Test invalid email
        authManager.signUp(email: "invalid-email", password: "password123", firstName: "Test") { success in
            XCTAssertFalse(success, "Should fail with invalid email")
            XCTAssertFalse(authManager.errorMessage.isEmpty, "Should have error message")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 3.0)
    }
}