extends RefCounted
## How a cart's weight (PlayerCart.weight: its preset's "weight", 0.85 for the lightest coupés to 1.25 for the Titan, 1
## the fleet's middle) tells in what it meets. Its mass is PlayerCart.BASE_MASS times its weight, and every driving force
## in PlayerCart scales with the mass, so it drives the same; what changes is the contact: a heavy car shoves a light
## one aside, pushes props (rigid bodies) further and keeps more of its speed, and is thrown less by a shockwave or a
## blast (they give every car the same push, so the change of speed goes as one over the weight). The scripted knocks
## (balls, brush, flags, tumbleweeds, rocks, poles, the herd) ask here. The differences are meant to be felt, not to
## decide races: about 15-25% either way.


## A body's weight (1 for anything that isn't a cart).
static func of(body: Object) -> float:
	if body == null or not is_instance_valid(body):
		return 1.0
	var w = body.get("weight")
	if w is float or w is int:
		return clampf(float(w), 0.5, 2.0)
	return 1.0


## The share of a speed loss the cart takes hitting something light (a ball, brush, a flag, a tumbleweed, a rock): a
## heavy car ploughs on, a light one is checked more.
static func loss_share(body: Object) -> float:
	return 1.0 / of(body)


## A speed kept (`keep`, 0..1, for the fleet's middle) for this cart: the loss (1 - keep) times `loss_share`.
static func keep(body: Object, keep_mid: float) -> float:
	return clampf(1.0 - (1.0 - keep_mid) * loss_share(body), 0.0, 1.0)


## How much harder than the fleet's middle the cart throws what it hits.
static func push_share(body: Object) -> float:
	return of(body)
