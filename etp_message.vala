/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2018 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
 *
 *  Netsukuku is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Netsukuku is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Netsukuku.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gee;
using TaskletSystem;

namespace Netsukuku.Qspn
{
    // Helper: path to send in a ETP
    internal EtpPath prepare_path_step_1(NodePath np)
    {
        EtpPath p = new EtpPath();
        p.hops = new ArrayList<HCoord>((a, b) => a.equals(b));
        p.hops.add_all(np.path.hops);
        p.arcs = new ArrayList<int>();
        p.arcs.add_all(np.path.arcs);
        p.fingerprint = np.path.fingerprint;
        p.nodes_inside = np.path.nodes_inside;
        p.cost = np.cost;
        return p;
    }
    internal void prepare_path_step_2(EtpPath p, ArrayList<HashMap<int, Destination>> destinations)
    {
        // Set values for ignore_outside.
        p.ignore_outside = new ArrayList<bool>();
        p.ignore_outside.add(false);
        for (int i = 1; i < QspnManager.levels; i++)
        {
            if (p.hops.last().lvl >= i)
            {
                int j = 0;
                while (true)
                {
                    if (p.hops[j].lvl >= i) break;
                    j++;
                }
                int d_lvl = p.hops[j].lvl;
                int d_pos = p.hops[j].pos;
                assert(destinations.size > d_lvl);
                if (! destinations[d_lvl].has_key(d_pos))
                {
                    if (p.cost.i_qspn_is_dead())
                    {
                        p.ignore_outside.add(false);
                        continue;
                    }
                    else assert_not_reached();
                }
                Destination d = destinations[d_lvl][d_pos];
                NodePath? best_to_arc = null;
                foreach (NodePath q in d.paths)
                {
                    if (q.path.arcs.last() == p.arcs[j])
                    {
                        if (best_to_arc == null)
                        {
                            best_to_arc = q;
                        }
                        else
                        {
                            if (q.cost.i_qspn_compare_to(best_to_arc.cost) < 0)
                            {
                                best_to_arc = q;
                            }
                        }
                    }
                }
                if (best_to_arc == null)
                {
                    p.ignore_outside.add(false);
                }
                else
                {
                    bool same = false;
                    if (best_to_arc.path.hops.size == j+1)
                    {
                        same = true;
                        for (int k = 0; k < j; k++)
                        {
                            if (!(best_to_arc.path.hops[k].equals(p.hops[k])) || 
                                best_to_arc.path.arcs[k] != p.arcs[k])
                            {
                                same = false;
                                break;
                            }
                        }
                    }
                    p.ignore_outside.add(!same);
                }
            }
            else
            {
                p.ignore_outside.add(true);
            }
        }
    }

    // Helper: check that an incoming ETP is valid:
    // The address MUST have the same topology parameters as mine.
    // The address MUST NOT be the same as mine.
    internal bool check_incoming_message(EtpMessage m, IQspnMyNaddr my_naddr)
    {
        if (m.node_address.i_qspn_get_levels() != QspnManager.levels) return false;
        bool not_same = false;
        for (int l = 0; l < QspnManager.levels; l++)
        {
            if (m.node_address.i_qspn_get_gsize(l) != QspnManager.gsizes[l]) return false;
            if (m.node_address.i_qspn_get_pos(l) != my_naddr.i_qspn_get_pos(l)) not_same = true;
        }
        if (! not_same) return false;
        return check_any_message(m);
    }
    // Helper: check that an outgoing ETP is valid:
    // The address MUST be mine.
    internal bool check_outgoing_message(EtpMessage m, IQspnMyNaddr my_naddr)
    {
        if (m.node_address.i_qspn_get_levels() != QspnManager.levels) return false;
        bool not_same = false;
        for (int l = 0; l < QspnManager.levels; l++)
        {
            if (m.node_address.i_qspn_get_gsize(l) != QspnManager.gsizes[l]) return false;
            if (m.node_address.i_qspn_get_pos(l) != my_naddr.i_qspn_get_pos(l)) not_same = true;
        }
        if (not_same) return false;
        return check_any_message(m);
    }
    // Helper: check that an ETP (both incoming or outgoing) is valid:
    // For each path p in P:
    //  . For i = p.hops.last().lvl+1 TO levels-1:
    //    . p.ignore_outside[i] must be true
    //  . p.fingerprint must be valid for p.hops.last().lvl
    //  . p.arcs.size MUST be the same of p.hops.size.
    //  . For each HCoord g in p.hops:
    //    . g.lvl has to be between 0 and levels-1
    //    . g.lvl has to grow only
    // With the main hops list of the ETP:
    //  . For each HCoord g in hops:
    //    . g.lvl has to be between 0 and levels-1
    //    . g.lvl has to grow only
    internal bool check_any_message(EtpMessage m)
    {
        if (! check_tplist(m.hops)) return false;
        foreach (EtpPath p in m.p_list)
        {
            for (int i = p.hops.last().lvl+1; i < QspnManager.levels; i++)
                if (! p.ignore_outside[i]) return false;
            if (p.fingerprint.i_qspn_get_level() != p.hops.last().lvl) return false;
            if (p.hops.size != p.arcs.size) return false;
            if (! check_tplist(p.hops)) return false;
        }
        return true;
    }
    internal bool check_tplist(Gee.List<HCoord> hops)
    {
        int curlvl = 0;
        foreach (HCoord c in hops)
        {
            if (c.lvl < curlvl) return false;
            if (c.lvl >= QspnManager.levels) return false;
            curlvl = c.lvl;
            if (c.pos < 0) return false;
        }
        return true;
    }
}
