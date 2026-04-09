class_name RpsResolver

## Pure RPS resolution logic with no Node dependencies.
## Delegates to the RPS autoload singleton.

static func resolve(player_move: int, enemy_move: int) -> int:
	return RPS.resolve(player_move, enemy_move)
