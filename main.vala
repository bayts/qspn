using Gee;
using Netsukuku;

namespace Netsukuku
{
    public void    log_debug(string msg)   {print(msg+"\n");}
    public void    log_trace(string msg)   {print(msg+"\n");}
    public void  log_verbose(string msg)   {print(msg+"\n");}
    public void     log_info(string msg)   {print(msg+"\n");}
    public void   log_notice(string msg)   {print(msg+"\n");}
    public void     log_warn(string msg)   {print(msg+"\n");}
    public void    log_error(string msg)   {print(msg+"\n");}
    public void log_critical(string msg)   {print(msg+"\n");}
}

public class MyEtp : ETP, IQspnEtp
{
    public MyEtp(MyNaddr start_node_naddr,
                 MyTPList etp_list,
                 Gee.List<MyNpath> known_paths,
                 Gee.List<MyFingerprint> start_node_fp,
                 int[] my_start_node_nodes_inside)
    {
        base(start_node_naddr, etp_list, known_paths, start_node_fp, my_start_node_nodes_inside);
    }

    // On a received ETP.
    // i_qspn_check_network_parameters(IQspnNaddr my_naddr);
    // i_qspn_tplist_adjust(HCoord exit_gnode);
    // i_qspn_tplist_acyclic_check(IQspnNaddr my_naddr);
    // i_qspn_routeset_cleanup(HCoord exit_gnode);
    // i_qspn_routeset_tplist_adjust(HCoord exit_gnode);
    // i_qspn_routeset_tplist_acyclic_check(IQspnNaddr my_naddr);
    // i_qspn_routeset_add_source(HCoord exit_gnode);
    // _routeset_getter();   (foreach IQspnPath p in x.routeset)
    
    // Builds an ETP to be forwarded
    // i_qspn_prepare_forward(HCoord exit_gnode);

    // On an ETP to be forwarded.
    // i_qspn_add_path(IQspnPath path);

    public bool i_qspn_check_network_parameters(IQspnNaddr my_naddr)
    {
        // check the tp-list
        // level has to be between 0 and levels-1
        // level has to grow only
        // pos has to be between 0 and gsize(level)-1
        int curlvl = 0;
        foreach (HCoord c in ((MyTPList)etp_list).get_hops())
        {
            if (c.lvl < curlvl) return false;
            if (c.lvl >= my_naddr.i_qspn_get_levels()) return false;
            curlvl = c.lvl;
            if (c.pos < 0) return false;
            if (c.pos >= my_naddr.i_qspn_get_gsize(c.lvl)) return false;
        }
        return true;
    }

    public void i_qspn_tplist_adjust(HCoord exit_gnode)
    {
        // grouping rule
        ArrayList<HCoord> hops = new ArrayList<HCoord>();
        hops.add(exit_gnode);
        foreach (HCoord c in ((MyTPList)etp_list).get_hops())
        {
            if (c.lvl >= exit_gnode.lvl)
            {
                hops.add(c);
            }
        }
        MyTPList n = new MyTPList(hops);
        etp_list = n;
    }

    public bool i_qspn_tplist_acyclic_check(IQspnNaddr my_naddr)
    {
        // acyclic rule
        foreach (HCoord c in ((MyTPList)etp_list).get_hops())
        {
            if (c.pos == my_naddr.i_qspn_get_pos(c.lvl)) return false;
        }
        return true;
    }

    public void i_qspn_routeset_cleanup(HCoord exit_gnode)
    {
        // remove paths internal to the exit_gnode
        int i = 0;
        while (i < known_paths.size)
        {
            MyNpath p = (MyNpath)known_paths[i];
            Gee.List<HCoord> l = p.i_qspn_get_following_hops();
            HCoord dest = l.last();
            if (dest.lvl < exit_gnode.lvl)
            {
                known_paths.remove_at(i);
            }
            else
            {
                i++;
            }
        }
    }

    public void i_qspn_routeset_tplist_adjust(HCoord exit_gnode)
    {
        foreach (Npath _p in known_paths)
        {
            MyNpath p = (MyNpath)_p;
            MyTPList lst_hops = p.get_lst_hops();
            // grouping rule
            ArrayList<HCoord> new_hops = new ArrayList<HCoord>();
            new_hops.add(exit_gnode);
            foreach (HCoord c in lst_hops.get_hops())
            {
                if (c.lvl >= exit_gnode.lvl)
                {
                    new_hops.add(c);
                }
            }
            MyTPList lst_new_hops = new MyTPList(new_hops);
            p.set_lst_hops(lst_new_hops);
        }
    }

    public void i_qspn_routeset_tplist_acyclic_check(IQspnNaddr my_naddr)
    {
        // remove paths that does not meet acyclic rule
        int i = 0;
        while (i < known_paths.size)
        {
            MyNpath p = (MyNpath)known_paths[i];
            // acyclic rule
            foreach (HCoord c in p.get_lst_hops().get_hops())
            {
                if (c.pos == my_naddr.i_qspn_get_pos(c.lvl))
                {
                    // unmet
                    known_paths.remove_at(i);
                }
                else
                {
                    i++;
                }
            }
        }
    }

    public void i_qspn_routeset_add_source(HCoord exit_gnode)
    {
        ArrayList<HCoord> to_exit_gnode_hops = new ArrayList<HCoord>();
        to_exit_gnode_hops.add(exit_gnode);
        MyTPList to_exit_gnode_list = new MyTPList(to_exit_gnode_hops);
        int nodes_inside = start_node_nodes_inside[exit_gnode.lvl];
        MyFingerprint fp = (MyFingerprint)start_node_fp[exit_gnode.lvl];
        REM nullrem = new MyREM(0); // TODO constructor MyREM.null() and MyREM.dead() 
        MyNpath to_exit_gnode = new MyNpath(to_exit_gnode_list,
                                            nodes_inside,
                                            (IQspnREM)nullrem,
                                            fp);
        known_paths.add(to_exit_gnode);
    }

    private ArrayList<Npath> real_routeset;
    private IQspnEtpRoutesetIterable my_routeset;
    public unowned IQspnEtpRoutesetIterable _routeset_getter()
    {
        my_routeset = new MyEtpRoutesetIterable(this);
        return my_routeset;
    }

    private class MyEtpRoutesetIterable : Object, IQspnEtpRoutesetIterable
    {
        private Iterator<Npath> it;
        public MyEtpRoutesetIterable(MyEtp etp)
        {
            it = etp.real_routeset.iterator();
        }

        public IQspnPath? next_value ()
        {
            if (! it.has_next()) return null;
            it.next();
            return (IQspnPath)it.@get();
        }
    }

    public IQspnEtp i_qspn_prepare_forward(HCoord exit_gnode)
    {
        // TODO
        return null;
    }

    public void i_qspn_add_path(IQspnPath path)
    {
        // TODO
    }

}

public class MyTPList : TPList
{
    public MyTPList(Gee.List<HCoord> hops)
    {
        base(hops);
    }

    public MyTPList.empty()
    {
        base(new ArrayList<HCoord>());
    }

    public Gee.List<HCoord> get_hops() {return hops;}
}

public class MyNpath : Npath, IQspnPath
{
    public MyNpath(MyTPList hops, int nodes_inside, IQspnREM cost, IQspnFingerprint fp)
    {
        base(hops, nodes_inside, (REM)cost, (FingerPrint)fp);
    }

    public MyTPList get_lst_hops()
    {
        return (MyTPList)hops;
    }

    public void set_lst_hops(MyTPList hops)
    {
        this.hops = hops;
    }

    public IQspnREM i_qspn_get_cost()
    {
        return (IQspnREM)cost;
    }

    public Gee.List<HCoord> i_qspn_get_following_hops()
    {
        return ((MyTPList)hops).get_hops();
    }

    public IQspnFingerprint i_qspn_get_fp()
    {
        return (IQspnFingerprint)fp;
    }

    public int i_qspn_get_nodes_inside()
    {
        return nodes_inside;
    }
}

public class MyNaddr : Naddr, IQspnNaddr, IQspnMyNaddr, IQspnPartialNaddr
{
    public MyNaddr(int[] pos, int[] sizes)
    {
        base(pos, sizes);
    }

    public int i_qspn_get_levels()
    {
        return sizes.size;
    }

    public int i_qspn_get_gsize(int level)
    {
        return sizes[level];
    }

    public int i_qspn_get_pos(int level)
    {
        return pos[level];
    }

    public int i_qspn_get_level_of_gnode()
    {
        int l = 0;
        while (l < pos.size)
        {
            if (pos[l] >= 0) return l;
            l++;
        }
        return pos.size; // the whole network
    }

    public IQspnPartialNaddr i_qspn_get_address_by_coord(HCoord dest)
    {
        int[] newpos = new int[pos.size];
        for (int i = 0; i < dest.lvl; i++) newpos[i] = -1;
        for (int i = dest.lvl; i < 9; i++) newpos[i] = pos[i];
        newpos[dest.lvl] = dest.pos;
        return new MyNaddr(newpos, sizes.to_array());
    }

    public HCoord i_qspn_get_coord_by_address(IQspnNaddr dest)
    {
        int l = pos.size-1;
        while (l >= 0)
        {
            if (pos[l] != dest.i_qspn_get_pos(l)) return new HCoord(l, dest.i_qspn_get_pos(l));
            l--;
        }
        // same naddr: error
        return new HCoord(-1, -1);
    }
}


public class MyNetworkID : Object, IQspnNetworkID
{
    public bool i_qspn_is_same_network(IQspnNetworkID other)
    {
        return true;
    }
}

public abstract class GenericNodeData : Object, IQspnNodeData
{
    private MyNetworkID netid;
    protected MyNaddr naddr;

    public GenericNodeData(MyNaddr naddr)
    {
        this.netid = new MyNetworkID();
        this.naddr = naddr;
    }

    public bool i_qspn_equals(IQspnNodeData other)
    {
        return this == (other as GenericNodeData);
    }

    public bool i_qspn_is_on_same_network(IQspnNodeData other)
    {
        return true;
    }

    public IQspnNetworkID i_qspn_get_netid()
    {
        return netid;
    }

    public IQspnNaddr i_qspn_get_naddr()
    {
        return (IQspnNaddr)naddr;
    }

    public abstract IQspnMyNaddr i_qspn_get_naddr_as_mine();
}

public class MyNodeData : GenericNodeData
{
    public MyNodeData(MyNaddr naddr) {base(naddr);}

    public override IQspnMyNaddr i_qspn_get_naddr_as_mine()
    {
        return (IQspnMyNaddr)naddr;
    }
}

public class OtherNodeData : GenericNodeData
{
    public OtherNodeData(MyNaddr naddr) {base(naddr);}

    public override IQspnMyNaddr i_qspn_get_naddr_as_mine()
    {
        assert(false); return null;
    }
}

public class MyREM : RTT, IQspnREM
{
    public MyREM(long usec_rtt) {base(usec_rtt);}

    public int i_qspn_compare_to(IQspnREM other)
    {
        return compare_to(other as MyREM);
    }

    public IQspnREM i_qspn_add_segment(IQspnREM other)
    {
        return new MyREM((other as MyREM).delay + delay);
    }
}

public class MyFingerprint : FingerPrint, IQspnFingerprint
{
    public MyFingerprint(int64 id, int[] elderships)
    {
        this.id = id;
        this.level = 0;
        this.elderships = elderships;
    }

    private MyFingerprint.empty() {}

    public bool i_qspn_equals(IQspnFingerprint other)
    {
        if (! (other is MyFingerprint)) return false;
        MyFingerprint _other = other as MyFingerprint;
        if (_other.id != id) return false;
        if (_other.level != level) return false;
        if (_other.elderships.length != elderships.length) return false;
        for (int i = 0; i < elderships.length; i++)
            if (_other.elderships[i] != elderships[i]) return false;
        return true;
    }

    public int i_qspn_level {
        get {
            return level;
        }
    }

    public IQspnFingerprint i_qspn_construct(Gee.List<IQspnFingerprint> fingers)
    {
        // given that:
        //  levels = level + elderships.length
        // do not construct for level = levels+1
        assert(elderships.length > 0);
        MyFingerprint ret = new MyFingerprint.empty();
        ret.level = level + 1;
        ret.id = id;
        ret.elderships = new int[elderships.length-1];
        for (int i = 1; i < elderships.length; i++)
            ret.elderships[i-1] = elderships[i];
        int cur_eldership = elderships[0];
        // start comparing
        foreach (IQspnFingerprint f in fingers)
        {
            assert(f is MyFingerprint);
            MyFingerprint _f = f as MyFingerprint;
            assert(_f.level == level);
            if (_f.elderships[0] < cur_eldership)
            {
                cur_eldership = _f.elderships[0];
                ret.id = _f.id;
            }
        }
        return ret;
    }
}

public class MyFingerprintManager : Object, IQspnFingerprintManager
{
    public long i_qspn_mismatch_timeout_msec(IQspnREM sum)
    {
        return (sum as MyREM).delay * 1000;
    }
}

public class MyArcRemover : Object, INeighborhoodArcRemover
{
    public void i_neighborhood_arc_remover_remove(INeighborhoodArc arc)
    {
        assert(false); // do not use in this fake
    }
}

public class MyMissingArcHandler : Object, INeighborhoodMissingArcHandler
{
    public void i_neighborhood_missing(INeighborhoodArc arc, INeighborhoodArcRemover arc_remover)
    {
        // do nothing in this fake
    }
}

public class MyArc : Object, INeighborhoodArc, IQspnArc
{
    public MyArc(string dest, IQspnNodeData node_data, IQspnREM cost)
    {
        this.dest = dest;
        this.node_data = node_data;
        this.qspn_cost = cost;
    }
    public string dest {get; private set;}
    private IQspnNodeData node_data;
    private IQspnREM qspn_cost;

    public IQspnNodeData i_qspn_get_node_data() {return node_data;}
    public IQspnREM i_qspn_get_cost() {return qspn_cost;}
    public bool i_qspn_equals(IQspnArc other) {return this == (other as MyArc);}

    // unused stuff
    public INeighborhoodNodeID i_neighborhood_neighbour_id {get {assert(false); return null;}} // do not use in this fake
    public string i_neighborhood_mac {get {assert(false); return null;}} // do not use in this fake
    public REM i_neighborhood_cost {get {assert(false); return null;}} // do not use in this fake
    public bool i_neighborhood_is_nic(INeighborhoodNetworkInterface nic) {assert(false); return false;} // do not use in this fake
    public bool i_neighborhood_equals(INeighborhoodArc other) {assert(false); return false;} // do not use in this fake
}

public class MyArcToStub : Object, INeighborhoodArcToStub
{
    public IAddressManagerRootDispatcher i_neighborhood_get_broadcast
    (INeighborhoodMissingArcHandler? missing_handler=null,
     INeighborhoodNodeID? ignore_neighbour=null)
    {
        assert(false); return null; // do not use in this fake
    }

    public IAddressManagerRootDispatcher i_neighborhood_get_broadcast_to_nic
    (INeighborhoodNetworkInterface nic,
     INeighborhoodMissingArcHandler? missing_handler=null,
     INeighborhoodNodeID? ignore_neighbour=null)
    {
        assert(false); return null; // do not use in this fake
    }

    public IAddressManagerRootDispatcher i_neighborhood_get_unicast
    (INeighborhoodArc arc, bool wait_reply=true)
    {
        assert(false); return null; // do not use in this fake
    }

    public IAddressManagerRootDispatcher i_neighborhood_get_tcp
    (INeighborhoodArc arc, bool wait_reply=true)
    {
        string dest = (arc as MyArc).dest;
        var ret = new AddressManagerTCPClient(dest, null, null, wait_reply);
        return ret;
    }
}

public class MyEtpFactory : Object, IQspnEtpFactory
{
    public IQspnPath i_qspn_create_path
                                (Gee.List<HCoord> hops,
                                IQspnFingerprint fp,
                                int nodes_inside,
                                IQspnREM cost)
    {
        // TODO
        return null;
    }

    public bool i_qspn_begin_etp()
    {
        // TODO
        return true;
    }

    public void i_qspn_abort_etp()
    {
        // TODO
    }

    public void i_qspn_set_my_naddr(IQspnNaddr my_naddr)
    {
        // TODO
    }

    public void i_qspn_set_gnode_fingerprint
                                (int level,
                                IQspnFingerprint fp)
    {
        // TODO
    }

    public void i_qspn_set_gnode_nodes_inside
                                (int level,
                                int nodes_inside)
    {
        // TODO
    }

    public void i_qspn_add_path(IQspnPath path)
    {
        // TODO
    }

    public IQspnEtp i_qspn_make_etp()
    {
        // TODO
        return null;
    }

}


int main(string[] args)
{
    // Register serializable types
    typeof(MyNaddr).class_peek();
    typeof(MyREM).class_peek();
    typeof(MyFingerprint).class_peek();

    // A network with 8 bits as address space. 3 to level 0, 2 to level 1, 3 to level 2.
    // Node 6 on gnode 2 on ggnode 1. PseudoIP 1.2.6
    MyNaddr addr1 = new MyNaddr({6, 2, 1}, {8, 4, 8});
    // PseudoIP 1.3.3
    MyNaddr addr2 = new MyNaddr({3, 3, 1}, {8, 4, 8});
    // PseudoIP 5.1.4
    MyNaddr addr3 = new MyNaddr({4, 1, 5}, {8, 4, 8});
    // fingerprints
    // first node in the network, also first g-node of level 2.
    MyFingerprint fp126 = new MyFingerprint(837425746848237, {0, 0, 0});
    // second in g-node 1
    MyFingerprint fp133 = new MyFingerprint(233468346784674, {0, 1, 0});
    // second g-node of level 2 in the network, first in g-node 5.
    MyFingerprint fp514 = new MyFingerprint(346634745457246, {0, 0, 1});
    // test calculation of fingerprints
    var i = new ArrayList<IQspnFingerprint>();
    IQspnFingerprint fp12 = fp126.i_qspn_construct(i);
    i = new ArrayList<IQspnFingerprint>();
    IQspnFingerprint fp13 = fp133.i_qspn_construct(i);
    i = new ArrayList<IQspnFingerprint>();
    i.add(fp12);
    IQspnFingerprint fp1 = fp13.i_qspn_construct(i);
    i = new ArrayList<IQspnFingerprint>();
    IQspnFingerprint fp51 = fp514.i_qspn_construct(i);
    i = new ArrayList<IQspnFingerprint>();
    IQspnFingerprint fp5 = fp51.i_qspn_construct(i);
    // nodes
    MyNodeData me = null;
    OtherNodeData v1 = null;
    OtherNodeData v2 = null;
    MyArc arc1 = null;
    MyArc arc2 = null;
    IQspnFingerprint fp;
    if (args[1] == "1")
    {
        me = new MyNodeData(addr1);
        fp = fp126;
        v1 = new OtherNodeData(addr2);
        arc1 = new MyArc("192.168.0.62", v1, new MyREM(1000));
        v2 = new OtherNodeData(addr3);
        arc2 = new MyArc("192.168.0.63", v2, new MyREM(1000));
    }
    else if (args[1] == "2")
    {
        me = new MyNodeData(addr2);
        fp = fp133;
        v1 = new OtherNodeData(addr1);
        arc1 = new MyArc("192.168.0.61", v1, new MyREM(1000));
        v2 = new OtherNodeData(addr3);
        arc2 = new MyArc("192.168.0.63", v2, new MyREM(1000));
    }
    else if (args[1] == "3")
    {
        me = new MyNodeData(addr3);
        fp = fp514;
        v1 = new OtherNodeData(addr2);
        arc1 = new MyArc("192.168.0.62", v1, new MyREM(1000));
        v2 = new OtherNodeData(addr1);
        arc2 = new MyArc("192.168.0.61", v2, new MyREM(1000));
    }
    else
    {
        return 1;
    }
    ArrayList<IQspnArc> arcs = new ArrayList<IQspnArc>();
    arcs.add(arc1);
    arcs.add(arc2);
    //
    QspnManager mgr = new QspnManager(me,
                                      4,
                                      0.7,
                                      arcs,
                                      fp,
                                      new MyArcToStub(),
                                      new MyFingerprintManager(),
                                      new MyEtpFactory());

    return 0;
}
