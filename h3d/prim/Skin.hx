package h3d.prim;

class Joint {

	public var bindId : Int;
	public var transPos : h3d.Matrix; // inverse pose matrix
	public var parent : Joint;
	public var subs : Array<Joint>;

	public function new() {
		bindId = -1;
		subs = [];
	}
	
}

private class Influence {
	public var j : Joint;
	public var w : Float;
	public function new(j, w) {
		this.j = j;
		this.w = w;
	}
}

class AnimCurve {
	public var joint : Joint;
	public var parent : AnimCurve;
	public var frames : Array<h3d.Matrix>;
	public var absolute : Bool; // tells if the frames are baked
	public function new(j) {
		this.joint = j;
	}
}

class Animation {
	
	public var skin : Skin;
	public var name : String;
	public var curves : Array<AnimCurve>;
	public var hcurves : IntHash<AnimCurve>;
	public var frameCount : Int;
	
	public function new(sk, n) {
		this.skin = sk;
		this.name = n;
		curves = [];
		hcurves = new IntHash();
	}
	
	public function computeAbsoluteFrames() {
		for( c in curves )
			if( !c.absolute )
				computeAnimFrames(c);
	}
	
	function computeAnimFrames( c : AnimCurve ) {
		if( c.absolute )
			return;
		c.absolute = true;
		if( c.parent == null ) {
			for( i in 0...frameCount ) {
				var m = c.frames[i];
				if( m == null ) break;
				m.multiply3x4(m, skin.preTransform);
			}
			return;
		}
		computeAnimFrames(c.parent);
		for( i in 0...frameCount ) {
			var m = c.frames[i];
			m.multiply3x4(m, c.parent.frames[i]);
		}
	}
	
	public function updateJoints( frame : Int, palette : Table<h3d.Matrix> ) {
		frame %= frameCount;
		for( c in curves ) {
			if( c.joint.bindId < 0 ) continue;
			var m = palette[c.joint.bindId];
			m.loadFrom(c.joint.transPos);
			var mf = c.frames[frame];
			if( mf != null ) m.multiply3x4(m, mf);
		}
	}
	
	public function allocPalette() {
		var max = -1;
		for( c in curves )
			if( c.joint.bindId >= max )
				max = c.joint.bindId;
		var a = new Table();
		for( i in 0...max + 1 )
			a.push(new h3d.Matrix());
		return a;
	}
	
}

private typedef Table<T> = #if flash flash.Vector<T> #else Array<T> #end

class Skin {
	
	public var vertexCount(default, null) : Int;
	public var bonesPerVertex(default,null) : Int;
	public var vertexJoints : Table<Int>;
	public var vertexWeights : Table<Float>;
	public var boundJoints : Array<Joint>;
	public var preTransform : h3d.Matrix;
	
	var envelop : Array<Array<Influence>>;
	
	public function new( vertexCount, bonesPerVertex ) {
		this.vertexCount = vertexCount;
		this.bonesPerVertex = bonesPerVertex;
		preTransform = h3d.Matrix.I();
		vertexJoints = new Table(#if flash vertexCount * bonesPerVertex #end);
		vertexWeights = new Table(#if flash vertexCount * bonesPerVertex #end);
		envelop = [];
	}
	
	inline function addInfluence( vid : Int, j : Joint, w : Float ) {
		var il = envelop[vid];
		if( il == null )
			il = envelop[vid] = [];
		il.push(new Influence(j,w));
	}

	function sortInfluences( i1 : Influence, i2 : Influence ) {
		return i2.w > i1.w ? 1 : -1;
	}
	
	function initWeights() {
		boundJoints = [];
		var pos = 0;
		for( i in 0...vertexCount ) {
			var il = envelop[i];
			if( il == null ) il = [];
			il.sort(sortInfluences);
			if( il.length > 4 )
				il = il.slice(0, 4);
			var tw = 0.;
			for( i in il )
				tw += i.w;
			tw = 1 / tw;
			for( i in 0...bonesPerVertex ) {
				var i = il[i];
				if( i == null ) {
					vertexJoints[pos] = 0;
					vertexWeights[pos] = 0;
				} else {
					if( i.j.bindId == -1 ) {
						i.j.bindId = boundJoints.length;
						boundJoints.push(i.j);
					}
					vertexJoints[pos] = i.j.bindId;
					vertexWeights[pos] = i.w;
				}
				pos++;
			}
		}
	}
	
}