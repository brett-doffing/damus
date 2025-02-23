//
//  ReplyTests.swift
//  damusTests
//
//  Created by William Casarin on 2022-05-08.
//

import XCTest
@testable import damus

class ReplyTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testMentionIsntReply() throws {
        let evid = NoteId(hex: "4090a9017a2beac3f17795d1aafb80d9f2b9eda97e4738501082ed5c927be014")!
        let content = "this is #[0] a mention"
        let tags = [evid.tag]
        let ev = NostrEvent(content: content, keypair: test_keypair, tags: tags)!
        let blocks = parse_note_content(content: .init(note: ev, privkey: test_keypair.privkey)).blocks
        let event_refs = interpret_event_refs(blocks: blocks, tags: ev.tags)

        XCTAssertEqual(event_refs.count, 1)
        
        let ref = event_refs[0]
        
        XCTAssertNil(ref.is_reply)
        XCTAssertNil(ref.is_thread_id)
        XCTAssertNil(ref.is_direct_reply)
        XCTAssertEqual(ref.is_mention, .some(.init(note_id: evid)))
    }
    
    func testUrlAnchorsAreNotHashtags() {
        let content = "this is my link: https://jb55.com/index.html#buybitcoin this is not a hashtag!"
        let blocks = parse_post_blocks(content: content)

        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].is_text, "this is my link: ")
        XCTAssertEqual(blocks[1].is_url, URL(string: "https://jb55.com/index.html#buybitcoin")!)
        XCTAssertEqual(blocks[2].is_text, " this is not a hashtag!")
    }

    func testLinkIsNotAHashtag() {
        let link = "https://github.com/damus-io/damus/blob/b7513f28fa1d31c2747865067256ad1d7cf43aac/damus/Nostr/NostrEvent.swift#L560"
        
        let content = "my \(link) link"
        let blocks = parse_post_blocks(content: content)
        
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].is_text, "my ")
        XCTAssertEqual(blocks[1].is_url, URL(string: link)!)
        XCTAssertEqual(blocks[2].is_text, " link")
    }
    
    func testAtAtEnd() {
        let content = "what @"
        let blocks = parse_post_blocks(content: content)
        
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].is_text, "what @")
    }
    
    func testHashtagsInQuote() {
        let content = "This is my \"#awesome post\""
        let blocks = parse_post_blocks(content: content)
        
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].is_text, "This is my \"")
        XCTAssertEqual(blocks[1].is_hashtag, "awesome")
        XCTAssertEqual(blocks[2].is_text, " post\"")
    }
    
    func testHashtagAtStartWorks() {
        let content = "#hashtag"
        let blocks = parse_post_blocks(content: content)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].is_hashtag, "hashtag")
    }
    
    func testGroupOfHashtags() {
        let content = "#hashtag#what#nope"
        let blocks = parse_post_blocks(content: content)
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].is_hashtag, "hashtag")
        XCTAssertEqual(blocks[1].is_hashtag, "what")
        XCTAssertEqual(blocks[2].is_hashtag, "nope")
    }
    
    func testRootReplyWithMention() throws {
        let content = "this is #[1] a mention"
        let thread_id = NoteId(hex: "c75e5cbafbefd5de2275f831c2a2386ea05ec5e5a78a5ccf60d467582db48945")!
        let mentioned_id = NoteId(hex: "5a534797e8cd3b9f4c1cf63e20e48bd0e8bd7f8c4d6353fbd576df000f6f54d3")!
        let tags = [thread_id.tag, mentioned_id.tag]
        let ev = NostrEvent(content: content, keypair: test_keypair, tags: tags)!
        let blocks = parse_note_content(content: .init(note: ev, privkey: test_keypair.privkey)).blocks
        let event_refs = interpret_event_refs(blocks: blocks, tags: ev.tags)

        XCTAssertEqual(event_refs.count, 2)
        XCTAssertNotNil(event_refs[0].is_reply)
        XCTAssertNotNil(event_refs[0].is_thread_id)
        XCTAssertNotNil(event_refs[0].is_reply)
        XCTAssertNotNil(event_refs[0].is_direct_reply)
        XCTAssertEqual(event_refs[0].is_reply, .some(NoteRef(note_id: thread_id)))
        XCTAssertEqual(event_refs[0].is_thread_id, .some(NoteRef(note_id: thread_id)))
        XCTAssertNotNil(event_refs[1].is_mention)
        XCTAssertEqual(event_refs[1].is_mention, .some(NoteRef(note_id: mentioned_id)))
    }
    
    func testEmptyMention() throws {
        let content = "this is some & content"
        let ev = NostrEvent(content: content, keypair: test_keypair, tags: [])!
        let blocks = parse_note_content(content: .init(note: ev, privkey: test_keypair.privkey)).blocks
        let post_blocks = parse_post_blocks(content: content)
        let post_tags = make_post_tags(post_blocks: post_blocks, tags: [])
        let event_refs = interpret_event_refs(blocks: blocks, tags: ev.tags)

        XCTAssertEqual(event_refs.count, 0)
        XCTAssertEqual(post_tags.blocks.count, 1)
        XCTAssertEqual(post_tags.tags.count, 0)
        XCTAssertEqual(post_blocks.count, 1)
    }

    func testManyMentions() throws {
        let content = "#[10]"
        let tags: [[String]] = [[],[],[],[],[],[],[],[],[],[],["p", "3e999f94e2cb34ef44a64b351141ac4e51b5121b2d31aed4a6c84602a1144692"]]
        let ev = NostrEvent(content: content, keypair: test_keypair, tags: tags)!
        let blocks = parse_note_content(content: .init(note: ev, privkey: test_keypair.privkey)).blocks
        let mentions = blocks.filter { $0.is_mention != nil }
        XCTAssertEqual(mentions.count, 1)
    }

    func testNewlineMentions() throws {
        let bech32_pk = "npub1xtscya34g58tk0z605fvr788k263gsu6cy9x0mhnm87echrgufzsevkk5s"
        let pk = bech32_pubkey_decode(bech32_pk)!

        let profile = Profile(name: "jb55")
        let post = user_tag_attr_string(profile: profile, pubkey: pk)
        post.append(.init(string: "\n"))
        post.append(user_tag_attr_string(profile: profile, pubkey: pk))
        post.append(.init(string: "\n"))

        let post_note = build_post(post: post, action: .posting(.none), uploadedMedias: [], references: [.pubkey(pk)])

        let expected_render = "nostr:\(pk.npub)\nnostr:\(pk.npub)"
        XCTAssertEqual(post_note.content, expected_render)

        let blocks = parse_note_content(content: .content(post_note.content,nil)).blocks
        let rendered = render_blocks(blocks: blocks)

        XCTAssertEqual(rendered, expected_render)

        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].is_mention, .any(.pubkey(pk)))
        XCTAssertEqual(blocks[1].is_text, "\n")
        XCTAssertEqual(blocks[2].is_mention, .any(.pubkey(pk)))
    }
    
    func testThreadedReply() throws {
        let content = "this is some content"
        let thread_id = NoteId(hex: "da256fb52146dc565c6c6b9ef906117c665864dc02b14a7b853eca244729c2f2")!
        let reply_id = NoteId(hex: "80093e9bdb495728f54cda2bad4aed096877189552b3d41264e73b9a9595be22")!
        let tags = [thread_id.tag, reply_id.tag]
        let ev = NostrEvent(content: content, keypair: test_keypair, tags: tags)!
        let blocks = parse_note_content(content: .init(note: ev, privkey: test_keypair.privkey)).blocks
        let event_refs = interpret_event_refs(blocks: blocks, tags: ev.tags)

        XCTAssertEqual(event_refs.count, 2)
        let r1 = event_refs[0]
        let r2 = event_refs[1]
        
        XCTAssertEqual(r1.is_thread_id, .some(.note_id(thread_id)))
        XCTAssertEqual(r2.is_reply, .some(.note_id(reply_id)))
        XCTAssertEqual(r2.is_direct_reply, .some(.note_id(reply_id)))
        XCTAssertNil(r1.is_direct_reply)
    }
    
    func testRootReply() throws {
        let content = "this is a reply"
        let thread_id = NoteId(hex: "53f60f5114c06f069ffe9da2bc033e533d09cae44d37a8462154a663771a4ce6")!
        let tags = [thread_id.tag]
        let ev = NostrEvent(content: content, keypair: test_keypair, tags: tags)!
        let blocks = parse_note_content(content: .content(ev.content,nil)).blocks
        let event_refs = interpret_event_refs(blocks: blocks, tags: ev.tags)

        XCTAssertEqual(event_refs.count, 1)
        let r = event_refs[0]
        
        XCTAssertEqual(r.is_direct_reply, .some(.note_id(thread_id)))
        XCTAssertEqual(r.is_reply, .some(.note_id(thread_id)))
        XCTAssertEqual(r.is_thread_id, .some(.note_id(thread_id)))
        XCTAssertNil(r.is_mention)
    }

    func testAdjacentComposedMention() throws {
        let content = "cc@jb55"

        let profile = Profile(name: "jb55")
        let tag = user_tag_attr_string(profile: profile, pubkey: test_pubkey)
        let appended = append_user_tag(tag: tag, post: .init(string: content), word_range: .init(2...6))
        let new_post = appended.post

        try new_post.testAttributes(conditions: [
            { let link = $0[.link] as? String; XCTAssertNil(link) },
            { let link = $0[.link] as! String; XCTAssertEqual(link, "damus:nostr:\(test_pubkey.npub)") },
            { let link = $0[.link] as? String; XCTAssertNil(link) }
        ])

        XCTAssertEqual(new_post.string, "cc @jb55 ")
    }

    func testAdjacentEmojiComposedMention() throws {
        let content = "😎@jb55"

        let profile = Profile(name: "jb55")
        let tag = user_tag_attr_string(profile: profile, pubkey: test_pubkey)
        let appended = append_user_tag(tag: tag, post: .init(string: content), word_range: .init(2...6))
        let new_post = appended.post

        try new_post.testAttributes(conditions: [
            { let link = $0[.link] as? String; XCTAssertNil(link) },
            { let link = $0[.link] as! String; XCTAssertEqual(link, "damus:nostr:\(test_pubkey.npub)") },
            { let link = $0[.link] as? String; XCTAssertNil(link) }
        ])

        XCTAssertEqual(new_post.string, "😎 @jb55 ")
    }

    func testComposedMentionNewline() throws {
        let content = """
        
        @jb55
        """

        let profile = Profile(name: "jb55")
        let tag = user_tag_attr_string(profile: profile, pubkey: test_pubkey)
        let appended = append_user_tag(tag: tag, post: .init(string: content), word_range: .init(1...5))
        let new_post = appended.post

        try new_post.testAttributes(conditions: [
            { let link = $0[.link] as? String; XCTAssertNil(link) },
            { let link = $0[.link] as! String; XCTAssertEqual(link, "damus:nostr:\(test_pubkey.npub)") },
            { let link = $0[.link] as? String; XCTAssertNil(link) },
        ])

        XCTAssertEqual(new_post.string, "\n@jb55 ")
    }

    func testComposedMention() throws {
        let content = "@jb55"

        let profile = Profile(name: "jb55")
        let tag = user_tag_attr_string(profile: profile, pubkey: test_pubkey)
        let appended = append_user_tag(tag: tag, post: .init(string: content), word_range: .init(0...4))
        let new_post = appended.post

        try new_post.testAttributes(conditions: [
            { let link = $0[.link] as! String; XCTAssertEqual(link, "damus:nostr:\(test_pubkey.npub)") },
            { let link = $0[.link] as? String; XCTAssertNil(link) },
        ])

        XCTAssertEqual(new_post.string, "@jb55 ")
    }

    func testAdjacentSpaceComposedMention() throws {
        let content = "cc @jb55"

        let profile = Profile(name: "jb55")
        let tag = user_tag_attr_string(profile: profile, pubkey: test_pubkey)
        let appended = append_user_tag(tag: tag, post: .init(string: content), word_range: .init(3...7))
        let new_post = appended.post

        try new_post.testAttributes(conditions: [
            { let link = $0[.link] as? String; XCTAssertNil(link) },
            { let link = $0[.link] as! String; XCTAssertEqual(link, "damus:nostr:\(test_pubkey.npub)") },
            { let link = $0[.link] as? String; XCTAssertNil(link) }
        ])

        XCTAssertEqual(new_post.string, "cc @jb55 ")
    }

    func testNoReply() throws {
        let content = "this is a #[0] reply"
        let ev = NostrEvent(content: content, keypair: test_keypair, tags: [])!
        let blocks = parse_note_content(content: .init(note: ev, privkey: test_keypair.privkey)).blocks
        let event_refs = interpret_event_refs(blocks: blocks, tags:ev.tags)

        XCTAssertEqual(event_refs.count, 0)
    }
    
    func testParseMention() throws {
        let note_id = NoteId(hex: "53f60f5114c06f069ffe9da2bc033e533d09cae44d37a8462154a663771a4ce6")!
        let tags = [note_id.tag]
        let ev = NostrEvent(content: "this is #[0] a mention", keypair: test_keypair, tags: tags)!
        let parsed = parse_note_content(content: .init(note: ev, privkey: test_keypair.privkey)).blocks

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed[0].is_text, "this is ")
        XCTAssertNotNil(parsed[1].is_mention)
        XCTAssertEqual(parsed[2].is_text, " a mention")
    }
    
    func testEmptyPostReference() throws {
        let parsed = parse_post_blocks(content: "")
        XCTAssertEqual(parsed.count, 0)
    }
    
    func testBech32MentionAtStart() throws {
        let pk = Pubkey(hex: "32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245")!
        let content = "@\(pk.npub) hello there"
        let blocks = parse_post_blocks(content: content)
        
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].is_mention, .any(.pubkey(pk)))
        XCTAssertEqual(blocks[1].is_text, " hello there")

    }
    
    func testBech32MentionAtEnd() throws {
        let pk = Pubkey(hex: "32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245")!
        let content = "this is a @\(pk.npub)"
        let blocks = parse_post_blocks(content: content)
        
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[1].is_mention, .any(.pubkey(pk)))
        XCTAssertEqual(blocks[0].is_text, "this is a ")
    }
    
    func testNpubMention() throws {
        let evid = NoteId(hex: "71ba3e5ddaf48103be294aa370e470fb60b6c8bca3fb01706eecd00054c2f588")!
        let pk = Pubkey(hex: "32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245")!
        let content = "this is a @\(pk.npub) mention"
        let blocks = parse_post_blocks(content: content)
        let post = NostrPost(content: content, references: [.event(evid)])
        let ev = post_to_event(post: post, keypair: test_keypair_full)!

        XCTAssertEqual(ev.tags.count, 2)
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[1].is_mention, .any(.pubkey(pk)))
        XCTAssertEqual(ev.content, "this is a nostr:npub1xtscya34g58tk0z605fvr788k263gsu6cy9x0mhnm87echrgufzsevkk5s mention")
    }
    
    func testNsecMention() throws {
        let evid = NoteId(hex: "71ba3e5ddaf48103be294aa370e470fb60b6c8bca3fb01706eecd00054c2f588")!
        let pk = Pubkey(hex: "ccf95d668650178defca5ac503693b6668eb77895f610178ff8ed9fe5cf9482e")!
        let nsec = "nsec1jmzdz7d0ldqctdxwm5fzue277ttng2pk28n2u8wntc2r4a0w96ssnyukg7"
        let content = "this is a @\(nsec) mention"
        let blocks = parse_post_blocks(content: content)
        let post = NostrPost(content: content, references: [.event(evid)])
        let ev = post_to_event(post: post, keypair: test_keypair_full)!

        XCTAssertEqual(ev.tags.count, 2)
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[1].is_mention, .any(.pubkey(pk)))
        XCTAssertEqual(ev.content, "this is a nostr:npub1enu46e5x2qtcmm72ttzsx6fmve5wkauftassz78l3mvluh8efqhqejf3v4 mention")
    }
    
    func testReplyMentions() throws {
        let pubkey  = Pubkey(hex: "30c6d1dc7f7c156794fa15055e651b758a61b99f50fcf759de59386050bf6ae2")!
        let thread_id = NoteId(hex: "a250fc93570c3e87f9c9b08d6b3ef7b8e05d346df8a52c69e30ffecdb178fb9e")!
        let reply_id = NoteId(hex: "9a180a10f16dac9566543ad1fc29616aab272b0cf123ab5d58843e16f4ef03a3")!

        let refs: [RefId]  = [
            .event(thread_id),
            .event(reply_id),
            .pubkey(pubkey)
        ]

        let post = NostrPost(content: "this is a (@\(pubkey.npub)) mention", references: refs)
        let ev = post_to_event(post: post, keypair: test_keypair_full)!
        
        XCTAssertEqual(ev.content, "this is a (nostr:\(pubkey.npub)) mention")
        XCTAssertEqual(ev.tags[2][1].string(), pubkey.description)
    }
    
    func testInvalidPostReference() throws {
        let pk = "32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e24"
        let content = "this is a @\(pk) mention"
        let parsed = parse_post_blocks(content: content)
        XCTAssertEqual(parsed.count, 1)
        guard case .text(let txt) = parsed[0] else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(txt, content)
    }
    
    func testInvalidPostReferenceEmptyAt() throws {
        let content = "this is a @ mention"
        let parsed = parse_post_blocks(content: content)
        XCTAssertEqual(parsed.count, 1)
        guard case .text(let txt) = parsed[0] else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(txt, content)
    }
    
    func testInvalidUriReference() throws {
        let id = "6fec2ee6cfff779fe8560976b3d9df782b74577f0caefa7a77c0ed4c3749b5de"
        let content = "this is a nostr:z:\(id) event mention"
        let parsed = parse_post_blocks(content: content)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed.count, 1)
        
        guard case .text(let txt) = parsed[0] else {
            XCTAssertTrue(false)
            return
        }
        
        XCTAssertEqual(txt, content)
    }
    
    func testParsePostUriPubkeyReference() throws {
        let id = Pubkey(hex: "6fec2ee6cfff779fe8560976b3d9df782b74577f0caefa7a77c0ed4c3749b5de")!
        let parsed = parse_post_blocks(content: "this is a nostr:\(id.npub) event mention")

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed[0].is_text, "this is a ")
        XCTAssertEqual(parsed[1].is_mention, .any(.pubkey(id)))
        XCTAssertEqual(parsed[2].is_text, " event mention")
        
        guard case .text(let t1) = parsed[0] else {
            XCTAssertTrue(false)
            return
        }
        XCTAssertEqual(t1, "this is a ")
        
        guard case .text(let t2) = parsed[2] else {
            XCTAssertTrue(false)
            return
        }
        XCTAssertEqual(t2, " event mention")
    }
    
    func testParsePostUriReference() throws {
        let id = NoteId(hex: "6fec2ee6cfff779fe8560976b3d9df782b74577f0caefa7a77c0ed4c3749b5de")!
        let parsed = parse_post_blocks(content: "this is a nostr:\(id.bech32) event mention")

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed[0].is_text, "this is a ")
        XCTAssertEqual(parsed[1].is_mention, .any(.note(id)))
        XCTAssertEqual(parsed[2].is_text, " event mention")

        guard case .text(let t1) = parsed[0] else {
            XCTAssertTrue(false)
            return
        }
        XCTAssertEqual(t1, "this is a ")
        
        guard case .text(let t2) = parsed[2] else {
            XCTAssertTrue(false)
            return
        }
        XCTAssertEqual(t2, " event mention")
    }
    
    func testParseInvalidMention() throws {
        let parsed = parse_note_content(content: .content("this is #[0] a mention",nil)).blocks

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed[0].is_text, "this is ")
        XCTAssertEqual(parsed[1].is_text, "#[0]")
        XCTAssertEqual(parsed[2].is_text, " a mention")
    }

}
