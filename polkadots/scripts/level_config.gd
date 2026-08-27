class_name PolkadotsLevelConfig

# num_options        : how many choices shown
# dot_density        : 0..100 percentage of letter pixels turned into dots
# dot_radius         : radius of each dot in pixels
# timeout_sec        : auto-advance as wrong after this many seconds
# rounds_per_level   : rounds before session ends
# option_display_sec : 0 = always visible; >0 = hide after N sec, show index numbers
# letter_size        : font size of options
# pass_pct           : accuracy (%) needed to move on. Below it the SAME level is played again.
#                      A level is `rounds_per_level` rounds long, so only a few percentages are
#                      even REACHABLE: out of 10 rounds a score is a multiple of 10, out of 12 it
#                      is 0/8/16/25/33/41/50/58/66/75/83/91/100. Set this to one of them, or the
#                      card promises a bar that cannot be met — "need 65%" out of 10 rounds really
#                      means 7/10, i.e. 70%. Recheck these whenever rounds_per_level changes.
#                      As set: 6/10, 6/10, 7/10, 7/10, 7/10, 9/12, 9/12, 10/12.

# don't use more than 5 options

const LEVELS: Array = [
	{"level": 1, "num_options": 3, "dot_density": 1.5, "dot_radius": 16.0, "timeout_sec": 4.0, "rounds_per_level": 10, "option_display_sec": 0.0, "letter_size": 120, "pass_pct": 60, 
	"bk_color": Color(0.7,0,0,1), "dot_color": Color(1,1,1,1), "letter_color": Color(1,1,1,1), },
	{"level": 2, "num_options": 3, "dot_density": 0.9, "dot_radius": 16.0, "timeout_sec": 4.0, "rounds_per_level": 10, "option_display_sec": 0.0, "letter_size": 110, "pass_pct": 60,
	"bk_color": Color(0,0.5,0,1), "dot_color": Color(1,1,1,1), "letter_color": Color(1,1,1,1), },
	{"level": 3, "num_options": 4, "dot_density": 0.5, "dot_radius": 12.0, "timeout_sec": 4.0, "rounds_per_level": 10, "option_display_sec": 0.0, "letter_size": 100, "pass_pct": 70,
	"bk_color": Color(0,0,0.8,1), "dot_color": Color(1,1,1,1), "letter_color": Color(1,1,1,1), },
	{"level": 4, "num_options": 4, "dot_density": 0.5, "dot_radius": 12.0, "timeout_sec": 3.0, "rounds_per_level": 10, "option_display_sec": 5.0, "letter_size": 100, "pass_pct": 70},
	{"level": 5, "num_options": 5, "dot_density": 0.4, "dot_radius": 10.0, "timeout_sec": 2.0, "rounds_per_level": 10, "option_display_sec": 4.0, "letter_size": 90, "pass_pct": 70},
	{"level": 6, "num_options": 5, "dot_density": 0.5, "dot_radius":  9.0, "timeout_sec": 2.0, "rounds_per_level": 12, "option_display_sec": 3.5, "letter_size": 90, "pass_pct": 75},
	{"level": 7, "num_options": 5, "dot_density": 0.5, "dot_radius":  8.0, "timeout_sec": 2.0, "rounds_per_level": 12, "option_display_sec": 3.0, "letter_size": 80, "pass_pct": 75},
	{"level": 8, "num_options": 5, "dot_density": 0.5, "dot_radius":  8.0, "timeout_sec": 2.0, "rounds_per_level": 12, "option_display_sec": 2.5, "letter_size": 80, "pass_pct": 83},
]

const default_bk_color: Color = Color(0.99, 0.79, 0.3, 1.0)
const default_letters_color: Color = Color.BLACK
const default_dots_color: Color = Color.BLACK

#   The agent icon sizes are in _cluster_agent_scale (line ~346):                                                                                                                                                                                                                               
#   3: return 0.19 if is_corner else 0.22                                                                                                                                                                                                                                                       
#   Reduce these if the sprites themselves overlap even when positions look right.                                                                                                                                                                                                              
                                                      
# ✻ Crunched for 2m 29s                                                                                                                                                                                                                                                                         
                                                                                          
# ❯ ok but what about the distance between elements in the cluster, and the distance of the cluster from the center?                                                                                                                                                                            
                                                                                                                                                                                                                                                                                              
# ● Distance of cluster from center — controlled by the lerp factor at line ~302:                                                                                                                                                                                                               
#   var base_px: Vector2 = center_px.lerp(edge_px, 0.7)                                                                                                                                                                                                                                         
#   0.7 means the cluster anchor sits 70% of the way from center to the edge. Increase → clusters move outward; decrease → move inward. This affects all clusters (all directions, all option counts) equally.                                                                                  
                                                                                                                                                                                                            
#   Distance between elements within a cluster — for the 3-option case, s (the overall spread) combined with the multipliers controls it:                                                                                                                                                       
#   - Outer point distance from base_px: s * 0.55                                                                                                                                                                                                                                               
#   - Inner pair distance from base_px (radially): s * 0.4                                                                                                                                                                                                                                      
#   - Inner pair distance from base_px (sideways): s * 0.6                                                                                                                                                                                                                                      
                                                                                                                                                                                                                                                                                              
#   So the gap between outer point and inner pair = (0.55 + 0.4) * s along the inward axis. Increasing s (line 320: t * 0.44 / t * 0.38) scales all three simultaneously. To change inter-element spacing without moving the cluster anchor, change s. To move the whole cluster without        
#   changing spacing, change the 0.7 lerp factor.    