/*
 * Copyright (c) 2018-2020 Ubimate Technologies Ltd and PageAmp contributors.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

package pageamp.core;

import pageamp.web.DomTools;
import pageamp.react.Value;
import pageamp.util.BaseNode;
using pageamp.web.DomTools;

class Text extends Node {
	public static inline var TEXT_PROP = Element.NODE_PREFIX + 'text';
	public var value(default,null): Value;
	public var text(default,null): String;

	public function new(parent:Element, text:String,
	                    ?n:DomTextNode, ?plug:String, ?index:Int) {
		this.text = text;
		this.node = n;
		this.plug = plug;
		this.index = index;
		super(parent, plug, index);
		if (isDynamicValue(null, text)) {
			var scope = getScope();
			if (scope != null) {
				value = scope.set(Element.NODE_PREFIX + page.nextId(), text);
				value.cb = textValueCB;
			}
		} else {
			textValueCB(null, null, text);
		}
	}

	// =========================================================================
	// abstract methods
	// =========================================================================

	override public function getDomNode(): DomNode {
		return t;
	}

	override public function cloneTo(parent:Node, index:Int, nesting=0): Node {
		var clone = new Text(cast parent, text, plug, this.index);
		return clone;
	}

	// =========================================================================
	// private
	// =========================================================================
	var node: DomTextNode;
	var plug: String;
	var index: Int;
	var t: DomTextNode;

	override function init() {
		super.init();
		t = node != null ? node : page.createDomTextNode('');
	}

	override function wasAdded(logicalParent:BaseNode,
	                           parent:BaseNode,
	                           ?i:Int) {
		if (node == null) {
			var p:DomElement = untyped parent.e;
			var b:Node = (i != null ? untyped parent.baseChildren[i] : null);
			p.domAddChild(t, b != null ? b.getDomNode() : null);
		}
	}

	override function wasRemoved(logicalParent:BaseNode, parent:BaseNode) {
		t.domRemove();
	}

	function textValueCB(u, n, v:Dynamic) {
		var s = (v != null ? Std.string(v) : '');
		t.domSetText(s);
	}

}